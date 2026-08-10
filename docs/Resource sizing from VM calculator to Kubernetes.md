# Resource sizing: from the VM calculator to Kubernetes

This document explains how to take the output of the internal VM-based resource calculator and translate it into Kubernetes resource requests and limits for both the **non-scaling** and the **scalable** Enterprise-AIO deployment variants.

## Details
--- PREVIEW ---

Note: *This is work-in-progress. Feedback is very welcome!*

## Background

The internal calculator is built around a traditional VM model: each service (Nextcloud, Redis, PostgreSQL/database, Collabora, Elasticsearch/fulltextsearch, Imaginary, ClamAV, Talk HPB) gets its own VM or group of VMs with a load balancer in front.

In Kubernetes the same services run as containers (Pods) inside a shared cluster. This changes the sizing logic in two fundamental ways:

1. **Requests vs. limits** — Kubernetes distinguishes between the resources a Pod is *guaranteed* (`requests`) and the maximum it is *allowed* to consume (`limits`). The scheduler uses `requests` to place Pods on nodes; `limits` cap runtime consumption.
2. **Static vs. autoscaled Pods** — Some Pods in Enterprise-AIO are horizontally autoscaled (HPA) based on CPU/memory utilisation. The per-replica resource spec, multiplied by the number of replicas, must equal the capacity previously modelled as multiple VMs.

---

## Step 1 — Run the VM calculator as usual

Run the calculator for the target user count and usage profile to obtain the per-service VM specification:

| Service | VM count | vCPU per VM | RAM per VM |
|---------|----------|-------------|------------|
| Nextcloud (Apache/PHP-FPM) | N | C | M |
| Redis | 1 | C | M |
| PostgreSQL | 1 | C | M |
| Collabora | K | C | M |
| Elasticsearch (fulltextsearch) | 1 | C | M |
| Imaginary | J | C | M |
| ClamAV | 1 | C | M |
| Talk HPB | 1 | C | M |

Keep these numbers as your **baseline totals**. All subsequent K8s values are derived from them.

---

## Step 2 — Choose the deployment variant

### Non-scaling variant
All services run as single-replica Pods inside the chart. `MAX_REPLICAS` is set to `1` (or left low). Suitable for small/medium installations where the cluster has enough headroom to schedule all Pods.

### Scalable variant
Stateless services (Nextcloud, Imaginary, Whiteboard) are horizontally autoscaled. Stateful services (Redis, PostgreSQL, Collabora, Elasticsearch) are either kept as single-replica bundled Pods or replaced by external scalable services. See the [Helm Chart readme](../nextcloud-enterprise-helm-chart/readme.md) for details on external service configuration.

---

## Step 3 — Choose your node tier and rounding interval

The rounding interval to use depends on the size of your cluster nodes. Smaller intervals allow for tighter bin-packing on small nodes; larger intervals reduce scheduling complexity on large nodes and avoid fragmentation.

| Node tier | Example node size | CPU interval | Memory interval |
|-----------|-------------------|--------------|-----------------|
| Small | 4 vCPU / 8–16 GiB | 250 m | 256 Mi |
| Medium | 8 vCPU / 32 GiB | 500 m | 512 Mi |
| Large | 16+ vCPU / 64+ GiB | 1000 m (1 core) | 1 Gi |

Always round **up** to the next interval for `requests` to avoid the scheduler placing a Pod on a node that cannot actually sustain it.

---

## Step 4 — Translate VM totals into K8s requests and limits

### The counting-down rule (requests)

The VM calculator outputs a *peak-capacity* figure for each VM. Kubernetes `requests` should reflect *sustained typical usage*, not the absolute peak, because:

- Multiple Pods share a node and peaks rarely coincide.
- The HPA triggers scale-out *before* a Pod hits its limit.

Apply a **request factor of 0.6–0.7** to the raw VM total for each service:

$$\text{CPU request per Pod} = \left\lceil \frac{\text{VM vCPU} \times 1000\,\text{m} \times 0.65}{\text{interval}} \right\rceil \times \text{interval}$$

$$\text{Memory request per Pod} = \left\lceil \frac{\text{VM RAM} \times 0.65}{\text{interval}} \right\rceil \times \text{interval}$$

### The counting-up rule (limits)

Set `limits` by counting **up** from the request. A factor of **1.5–2×** the request is typical:

$$\text{CPU limit} = \text{CPU request} \times 1.5 \quad \text{(round up to interval)}$$

$$\text{Memory limit} = \text{Memory request} \times 2 \quad \text{(round up to interval)}$$

Memory limits should be at or below the full VM RAM spec so that a runaway Pod cannot consume more than was originally provisioned.

---

## Step 5 — Apply per-variant adjustments

### Non-scaling variant

Each service maps to exactly one Pod. Apply Step 4 directly to each VM row. The resulting `requests` and `limits` are set in `values.yaml` via the corresponding `*_RESOURCES` key.

**Example** (medium nodes, Nextcloud VM: 4 vCPU / 8 GiB):

```yaml
NEXTCLOUD_RESOURCES:
  requests:
    cpu: "2500m"     # 4 × 1000 × 0.65 = 2600 → rounded down to nearest 500 m interval
    memory: "5Gi"    # 8 × 0.65 = 5.2 → rounded up to nearest 512 Mi = 5.5 GiB → use 5 Gi for tight fit
  limits:
    cpu: "4000m"     # 2500 × 1.5 = 3750 → rounded up to next 500 m = 4000 m
    memory: "8Gi"    # 5 × 2 = 10 → capped at original VM RAM = 8 Gi
```

> Set `MAX_REPLICAS: 1` (or `VPA_ENABLED: "no"` with manual resources) to keep HPA from spinning up unnecessary replicas when you have no headroom.

### Scalable variant

For **autoscaled services** (Nextcloud, Imaginary, Whiteboard), the VM calculator may have sized *N* VMs behind a load balancer. Translate this as follows:

1. **Minimum replicas** — set `MIN_REPLICAS` to `1` (default) or `2` for HA.
2. **Per-replica request** — count down from a *single* VM spec (not the total across all N VMs). The HPA will scale out additional replicas to reach the equivalent of N × VM when needed.
3. **`MAX_REPLICAS`** — set to `N` (the number of VMs the calculator sized), so the cluster can scale out to match the full capacity headroom.

$$\text{CPU request}_{\text{per replica}} = \left\lceil \frac{\text{1 VM vCPU} \times 1000\,\text{m} \times 0.65}{\text{interval}} \right\rceil \times \text{interval}$$

**Example** (large nodes, calculator sized 3 × Nextcloud VMs, each 8 vCPU / 16 GiB):

```yaml
MAX_REPLICAS: 3          # matches the 3-VM LB pool from the calculator

NEXTCLOUD_RESOURCES:
  requests:
    cpu: "5000m"         # 8 × 1000 × 0.65 = 5200 → rounded down to nearest 1000 m
    memory: "10Gi"       # 16 × 0.65 = 10.4 → rounded up to nearest 1 Gi
  limits:
    cpu: "12000m"        # 5000 × 1.5 = 7500 → but cap at full VM = 8000 m; bump to 12 cores if node allows
    memory: "16Gi"       # capped at original VM RAM
```

For **stateful / non-autoscaled bundled services** (Redis, PostgreSQL, Collabora, Elasticsearch) the same counting-down/up approach from the non-scaling section applies directly — one VM → one Pod.

For **externally provided scalable services** (external Redis cluster, external PostgreSQL, external Collabora farm) the K8s resource spec is governed by those charts/operators and is out of scope here. Use the VM-calculator outputs as input to the respective Bitnami or operator sizing guides.

---

## Step 6 — Validate total cluster capacity

Before applying, sum up all `requests` across all Pods and compare against the available allocatable capacity of your cluster nodes.

```
total CPU requests  ≤  sum of allocatable CPU across all worker nodes  ×  0.8
total RAM requests  ≤  sum of allocatable RAM across all worker nodes  ×  0.8
```

The 0.8 factor reserves headroom for system Pods, DaemonSets, and burst traffic. If the check fails, either add nodes or revisit the request factor in Step 4 (down to 0.5 is reasonable for dev/staging; stay at 0.65 for production).

---

## Step 7 — Configure values.yaml

Fill in the `*_RESOURCES` keys for each enabled service. The full list of available keys is:

```yaml
APACHE_RESOURCES:
CLAMAV_RESOURCES:
COLLABORA_RESOURCES:
DATABASE_RESOURCES:
FULLTEXTSEARCH_RESOURCES:
IMAGINARY_RESOURCES:
NEXTCLOUD_RESOURCES:
NEXTCLOUD_MANAGEMENT_RESOURCES:
NOTIFY_PUSH_RESOURCES:
ONLYOFFICE_RESOURCES:
REDIS_RESOURCES:
TALK_RESOURCES:
TALK_RECORDING_RESOURCES:
WHITEBOARD_RESOURCES:
```

The nginx subchart uses a separate key and supports Bitnami resource presets:

```yaml
nginx:
  resourcesPreset: medium   # small | medium | large | xlarge | 2xlarge
  # or manually:
  # resources:
  #   requests:
  #     cpu: "500m"
  #     memory: "256Mi"
  #   limits:
  #     cpu: "2000m"
  #     memory: "1Gi"
```

See [Resource requests and limits](./Resource%20requests%20and%20limits.md) for the format reference and the upgrade command.

---

## Step 8 — Monitor and refine

After deployment, observe actual utilisation and compare it to requests:

```bash
kubectl top pods -n <namespace>
```

- If actual CPU/memory is **consistently below 40 % of the request**, count the request down by one interval.
- If Pods are **frequently OOMKilled or CPU-throttled**, count the limit up by one interval, or the request up if throttling persists.
- For autoscaled deployments, check HPA status to verify replicas are scaling as expected:

```bash
kubectl get hpa -n <namespace>
```

Adjust `MAX_REPLICAS` if the HPA is hitting its ceiling before the VM-calculator's N-VM equivalent is reached.

---

## Quick-reference summary

| Step | Non-scaling variant | Scalable variant |
|------|--------------------|--------------------|
| 1 | Run VM calculator | Run VM calculator |
| 2 | `MAX_REPLICAS: 1` | `MAX_REPLICAS: N` (= VM count per service) |
| 3 | Choose node tier → pick interval | Choose node tier → pick interval |
| 4 | Request = VM spec × 0.65, rounded up to interval | Request = **1 VM spec** × 0.65, rounded up to interval |
| 5 | Limit = request × 1.5–2, capped at VM spec | Same, applied per replica |
| 6 | Validate sum of requests ≤ cluster capacity × 0.8 | Validate sum at MAX_REPLICAS ≤ cluster capacity × 0.8 |
| 7 | Set `*_RESOURCES` in `values.yaml`, then `helm upgrade` | Set `*_RESOURCES` + `MAX_REPLICAS` in `values.yaml`, then `helm upgrade` |
| 8 | Monitor with `kubectl top` and refine | Monitor HPA + `kubectl top` and refine |
