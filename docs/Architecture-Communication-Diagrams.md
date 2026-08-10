# Architecture Communication Diagrams for E-AIO

## Details
--- PREVIEW ---

> **Policy compliance** — every single connection is documented with:
> 1. **Why** the connection exists
> 2. **What data** is transferred
> 3. **Which protocol** is used
> 4. **Whether it is encrypted**
>
> Connections are numbered on the diagram arrows and cross-referenced with the detail tables below each diagram.

**Legend**

| Symbol | Meaning |
|--------|---------|
| 🔒 | Traffic is encrypted (TLS / DTLS-SRTP) |
| 🌐 | Traffic is **not** encrypted (cluster-internal only) |
| ⚠️ | Encryption is **optional / configurable** |

---

## 1. Non-Scalable — All Bundled Services

All services are deployed inside a single Helm release. Apache+Caddy terminates TLS directly and is the sole external entry point (except Talk STUN/TURN). PostgreSQL, Redis, Collabora, OnlyOffice, ClamAV, Elasticsearch, Imaginary, Whiteboard, Talk and Talk-Recording all run as bundled pods.

[![Diagram of non-scalable services](./Architecture%20Communication%20Diagrams%20non-scalable.svg "Click to open image for zooming")](./Architecture%20Communication%20Diagrams%20non-scalable.svg)

> Egress connections to external services are identical in both deployment modes — see **[§ 3 — Egress Connections (both modes)](#3-egress-connections--both-modes)** below.

### Connection Details — Non-Scalable

| # | From | To | Why | Data Transferred | Protocol | Encrypted |
|---|------|----|-----|------------------|----------|-----------|
| ① | Internet | Apache+Caddy `:443` | Entry point for all web browsers, desktop clients, mobile apps, WebDAV mounts, and some optional containers | HTTP requests, file uploads/downloads, WebDAV operations, authentication payloads | HTTPS (HTTP/1.1, HTTP/2, HTTP/3) over TCP+UDP | **Yes** — TLS; certificate managed by Caddy (automatic ACME) |
| ② | Internet | Talk TURN `:3478` | STUN peer-discovery and TURN relay so clients behind NAT/firewalls can join Talk calls | STUN binding requests, TURN channel allocations | STUN/TURN over TCP+UDP | **Yes** — DTLS for channel setup |
| ③ | Apache+Caddy | Nextcloud `:9000` | Delegate PHP execution to the FPM worker pool for every web request | FastCGI environment (request headers, method, URI), request body, PHP response body | FastCGI over TCP | **No** — cluster-internal; protected by Kubernetes network boundaries |
| ④ | Apache+Caddy | Notify-Push `:7867` | Reverse-proxy the `/push/` path so clients receive real-time file-change notifications on the same origin | Outgoing push event data | HTTP / WebSocket | **No** — cluster-internal |
| ⑤ | Apache+Caddy | Collabora Online `:9980` | Reverse-proxy the paths `/browser`, `/hosting`, `/cool`, `/lool` for the Collabora office so it is served under the Nextcloud domain | Collabora Web UI assets, WOPI bridge requests, WebSocket editor messages | HTTP / WebSocket | **No** — cluster-internal |
| ⑥ | Apache+Caddy | OnlyOffice `:80` | Reverse-proxy the path `/onlyoffice` for the OnlyOffice Document Server so it is served under the Nextcloud domain | OnlyOffice UI assets, document API callbacks, WebSocket editor messages | HTTP / WebSocket | **No** — cluster-internal |
| ⑦ | Apache+Caddy | Talk HPB `:8081` | Reverse-proxy the path `/standalone-signaling/` so Talk clients can connect to the HPB under the Nextcloud domain | WebSocket handshake and signaling messages for Talk rooms | HTTP / WebSocket | **No** — cluster-internal |
| ⑧ | Nextcloud | PostgreSQL `:5432` | Persistent storage of all Nextcloud application data | Application and user-generated data | PostgreSQL wire protocol over TCP | **No** — cluster-internal |
| ⑨ | Nextcloud | Redis `:6379` | Session management, distributed file-locking, and application-level caching | PHP session payloads, file lock tokens, transient app data, preview cache entries | Redis RESP protocol over TCP | **No** — cluster-internal |
| ⑩ | Nextcloud | ClamAV `:3310` | Real-time antivirus scan of every uploaded file before it is stored | File data | clamd TCP protocol | **No** — cluster-internal |
| ⑪ | Nextcloud | Imaginary `:9000` | Offload CPU-intensive image preview and thumbnail generation from the PHP process | Raw source image data and transformation parameters; processed preview image returned | HTTP REST API | **No** — cluster-internal |
| ⑫ | Nextcloud | Elasticsearch `:9200` | Index file content and execute full-text search queries across the Nextcloud file store | Document text content and metadata for indexing; Elasticsearch Query DSL and ranked result sets | HTTP REST API | **No** — cluster-internal |
| ⑬ | Nextcloud | Collabora `:9980` (WOPI host) | Fetch information about the service | Server metadata, version numbers, feature flags. | HTTP (WOPI) | **No** — cluster-internal |
| ⑭ | Nextcloud | OnlyOffice `:80` | Fetch information about the service | Server metadata, version numbers, feature flags. | HTTP REST API | **No** — cluster-internal |
| ⑮ | Nextcloud | Whiteboard `:3002` | Fetch information about the service | Server metadata, version numbers, feature flags. | HTTP | **No** — cluster-internal |
| ⑯ | Nextcloud | S3 Object Storage `:OBJECTSTORE_S3_PORT` | Store and retrieve user-uploaded file data, versioned files, and generated previews | Binary file blobs, object metadata, multi-part upload chunks | S3 REST API | **Yes** TLS controlled by `OBJECTSTORE_S3_SSL` |
| ⑰ | Nextcloud | NFS / PVC (NC app files) | Read Nextcloud PHP sources, static assets, and configuration at runtime | PHP files, JavaScript/CSS/image assets, `config.php` | Kubernetes RWX volume mount (NFS or PVC) | **No** |
| ⑱ | Nextcloud Management | PostgreSQL `:5432` | Initialise the database schema on first install; run schema migrations and post-update optimisations | Application and user-generated data | PostgreSQL wire protocol over TCP | **No** — cluster-internal |
| ⑲ | Nextcloud Management | Redis `:6379` | Flush stale cache entries and configure Redis after a Nextcloud version update | Configuration commands; cache seed data | Redis RESP protocol over TCP | **No** — cluster-internal |
| ㉑ | Notify-Push | Nextcloud Management `:9001` | Pod status check | None | TCP | **No** — cluster-internal |
| ㉒ | Notify-Push | Redis `:6379` | Subscribe to file-change events published by Nextcloud so they can be forwarded as push notifications to clients | File-change event messages | Redis RESP protocol over TCP | **No** — cluster-internal |
| ㉓ | Whiteboard | Redis `:6379` | Persist the collaborative whiteboard canvas state across client reconnects and pod restarts | Application data and session tokens | Redis RESP protocol over TCP | **No** — cluster-internal |
| ㉔ | Whiteboard | Apache+Caddy `:443` | Fetch and save content data | File metadata and document content | HTTPS | **Yes** — TLS |
| ㉕ | Collabora Online | Apache+Caddy `:443` | Fetch and save content data | File metadata and document content | HTTPS | **Yes** — TLS |
| ㉖ | OnlyOffice | Apache+Caddy `:443` | Fetch and save content data | File metadata and document content | HTTPS | **Yes** — TLS |
| ㉗ | Talk HPB | Apache+Caddy `:443` | Authenticate signaling participants and retrieve room and backend configuration from the Nextcloud Talk API | Shared-secret auth tokens, Nextcloud Talk room metadata, signaling backend configuration | HTTPS | **Yes** — TLS |
| ㉘ | Talk-Recording |  Talk HPB `:8081` | Send internal recording control commands (start, pause, stop, status query) to the HPB | Recording session control messages, internal shared secret | HTTP | **No** — cluster-internal |
| ㉙ | Talk-Recording | Apache+Caddy `:443` | Upload the completed call recording to Nextcloud | Recording file content | HTTPS | **Yes** — TLS |

> Egress connections (E-1 … E-11) are detailed in **[§ 3 — Egress Connections (both modes)](#3-egress-connections--both-modes)** below.

---

## 2. Scalable — External Services

The scalable Enterprise AIO Helm chart is reduced to the core Nextcloud PHP stack, Nginx webserver (subchart), Nextcloud Management, Notify-Push, Imaginary, Whiteboard, and optionally ClamAV and Talk-Recording (both of the latter are not scalable, yet, for technical reasons).

PostgreSQL, Redis, Collabora Online, Elasticsearch, OnlyOffice, and Talk (including a TURN service) must be provided externally. For recommendations read [our documentation](https://github.com/nextcloud-gmbh/enterprise-aio/blob/main/nextcloud-enterprise-helm-chart/readme.md#scalable-base-nextcloud-installation). The following details assume that these services are run in the same Kubernetes cluster, and have their external traffic terminated at the central Ingress controller.

TLS is terminated at the shared Nginx Ingress Controller.

> **Configurable ports** — Several connection ports are controlled by `values.yaml` variables. The diagram and table show each variable name alongside its default value. Only the external-service ports (PostgreSQL, Redis, Elasticsearch, Talk/TURN, SMTP, S3) are variable; internal service ports are fixed by the chart.

> **Encryption for external services** — TLS can be enabled for connections to external PostgreSQL (`NEXTCLOUD_TRUSTED_CERTIFICATES.POSTGRES: "yes"`), external MySQL/MariaDB (`NEXTCLOUD_TRUSTED_CERTIFICATES.MYSQL: "yes"`), external SMTP (`NEXTCLOUD_TRUSTED_CERTIFICATES.MAILER: "yes"`), and external Redis (`NEXTCLOUD_TRUSTED_CERTIFICATES.REDIS: "yes"`). For external Elasticsearch, set `FULLTEXTSEARCH_PROTOCOL: https`. Custom CA certificates must be added via the `NEXTCLOUD_TRUSTED_CERTIFICATES` map in `values.yaml`. These options only affect connections **from** Nextcloud.

[![Diagram of scalable services](./Architecture%20Communication%20Diagrams%20scalable.svg "Click to open image for zooming")](./Architecture%20Communication%20Diagrams%20scalable.svg)

> Egress connections to external services are identical in both deployment modes — see **[§ 3 — Egress Connections (both modes)](#3-egress-connections--both-modes)** below.

### Connection Details — Scalable

> **Variables referenced in this table**
>
> | Variable | Default | Scope |
> |----------|---------|-------|
> | `POSTGRES_PORT` | `5432` | External PostgreSQL / MySQL port |
> | `DATABASE_TYPE` | `postgres` | `postgres` or `mysql` — selects the DB driver |
> | `REDIS_PORT` | `6379` | External Redis primary port (`REDIS_PORT_2`…`REDIS_PORT_9` for cluster nodes) |
> | `REDIS_MODE` | `redis` | `redis` or `rediscluster` |
> | `FULLTEXTSEARCH_PORT` | `9200` | External Elasticsearch port |
> | `FULLTEXTSEARCH_PROTOCOL` | `http` | `http` or `https` — selects plain or TLS for Elasticsearch |
> | `TALK_PORT` | `3478` | Talk STUN/TURN public port (must be > 1024) |
> | `OBJECTSTORE_S3_PORT` | *(empty — use protocol default)* | S3-compatible object storage port |

| # | From | To | Why | Data Transferred | Protocol | Encrypted |
|---|------|----|-----|------------------|----------|-----------|
| ① | Internet | Nginx Ingress Controller `NC_DOMAIN:443` | Entry point for all Nextcloud web traffic | Everything | HTTPS (HTTP/1.1, HTTP/2) over TCP | **Yes** — TLS terminated at the Ingress Controller; certificates managed by cert-manager |
| ② | Internet | TURN Server `TALK_PORT` (default: 3478) / `:20000-40000` | STUN peer-discovery and TURN media relay for Talk video/audio calls | STUN binding requests, TURN channel allocations, WebRTC media packets | STUN/TURN over TCP+UDP `TALK_PORT`; UDP `:20000-40000` | **Yes** — DTLS for channel setup, SRTP for media payload |
| ③ | Internet | Nginx Ingress Controller `COLLABORA_HOST:443` | Access to the Collabora Online editor UI on its dedicated domain | Collabora Web UI assets, WebSocket editor messages | HTTPS over TCP | **Yes** — TLS terminated at Ingress |
| ④ | Internet | Nginx Ingress Controller `TALK_HOST:443` | Access to the Talk HPB signaling server on its dedicated domain | WebSocket signaling messages for Talk rooms | HTTPS / WebSocket over TCP | **Yes** — TLS terminated at Ingress |
| ⑤ | Nginx Ingress Controller | Nginx webserver subchart `:80` | Forward Nextcloud domain traffic to the webserver after TLS termination | Nextcloud application and user data | HTTP | **No** — cluster-internal |
| ⑥ | Nginx Ingress Controller | Collabora (port as configured in external helm chart) | Forward Collabora domain traffic to the Collabora Helm service after TLS termination | Collabora UI and WOPI bridge traffic | HTTP / WebSocket | **No** — cluster-internal |
| ⑦ | Nginx Ingress Controller | OnlyOffice Document Server `ONLYOFFICE_HOST:` (port as configured in external helm chart) | Forward OnlyOffice domain traffic to the OnlyOffice Helm service | Editor assets, document API calls | HTTP / WebSocket | **No** — cluster-internal |
| ⑧ | Nginx Ingress Controller | Talk HPB (port as configured in external helm chart) | Forward Talk domain traffic to the HPB service after TLS termination | Signaling messages | HTTP / WebSocket | **No** — cluster-internal |
| ⑨ | Nginx webserver subchart | Nextcloud `:9000` | Delegate PHP execution to the FPM worker pool | FastCGI environment (headers, method, URI), request body, PHP response body | FastCGI over TCP | **No** — cluster-internal |
| ⑩ | Nginx webserver subchart | Notify-Push `:7867` | Reverse-proxy `/push/` so clients receive file-change notifications on the Nextcloud origin | Outgoing push event data | HTTP / WebSocket | **No** — cluster-internal |
| ⑪ | Nextcloud | PostgreSQL Cluster `POSTGRES_PORT` (default: 5432) | Persistent storage of all Nextcloud application data | Application and user-generated data | PostgreSQL wire protocol over TCP | **Optional** ⚠️ — TLS enabled by setting `NEXTCLOUD_TRUSTED_CERTIFICATES.POSTGRES: "yes"` (for PostgreSQL) or `NEXTCLOUD_TRUSTED_CERTIFICATES.MYSQL: "yes"` (for MySQL/MariaDB); supply a custom CA via `NEXTCLOUD_TRUSTED_CERTIFICATES` |
| ⑫ | Nextcloud | Redis / Redis Cluster `REDIS_PORT` (default: 6379), or `REDIS_PORT_*` (for Redis Cluster) | Session management, distributed file-locking, and application-level caching | PHP session payloads, file lock tokens, transient app data, cache entries | Redis RESP protocol over TCP port `REDIS_PORT` or `REDIS_PORT_*` | **Optional** ⚠️ — TLS enabled by setting `NEXTCLOUD_TRUSTED_CERTIFICATES.REDIS: "yes"`; supply a custom CA via `NEXTCLOUD_TRUSTED_CERTIFICATES`  |
| ⑬ | Nextcloud | ClamAV `:3310` | Real-time antivirus scan of every uploaded file before it is stored | File data | clamd TCP protocol | **No** — cluster-internal |
| ⑭ | Nextcloud | Imaginary `:9000` | Offload CPU-intensive image preview and thumbnail generation from the PHP process | Raw source image data and transformation parameters; processed preview image returned | HTTP REST API | **No** — cluster-internal |
| ⑮ | Nextcloud | Elasticsearch `FULLTEXTSEARCH_PORT` (default: 9200) | Index file content and execute full-text search queries across the Nextcloud file store | Document text content and metadata for indexing; Elasticsearch Query DSL and ranked result sets | `FULLTEXTSEARCH_PROTOCOL` (default: `http`, set to `https` for TLS) REST API | **Optional** ⚠️ — TLS enabled by setting `FULLTEXTSEARCH_PROTOCOL: https`; supply a custom CA via `NEXTCLOUD_TRUSTED_CERTIFICATES` |
| ⑯ | Nextcloud | Nginx Ingress Controller `COLLABORA_HOST:443` | Fetch information about the service | Server metadata, version numbers, feature flags. | HTTPS (WOPI REST) | **Yes** — full external TLS round-trip through the Ingress |
| ⑰ | Nextcloud | OnlyOffice Document Server `:80` (external Helm chart) | Fetch information about the service | Server metadata, version numbers, feature flags. | HTTP REST API | **No** — cluster-internal |
| ⑱ | Nextcloud | Whiteboard `:3002` | Fetch information about the service | Server metadata, version numbers, feature flags. | HTTP | **No** — cluster-internal |
| ⑲ | Nextcloud | Object Storage (`:OBJECTSTORE_S3_PORT`) | Store and retrieve user-uploaded file data, versioned files, and generated previews | Binary file blobs, object metadata, multi-part upload chunks | S3 REST API over port `OBJECTSTORE_S3_PORT` (`OBJECTSTORE_S3_*`) | **Yes** TLS controlled by `OBJECTSTORE_S3_SSL` (default: `true`) |
| ⑳ |  | NFS / PVC (NC app files) | Read Nextcloud PHP sources, static assets, and configuration at runtime | PHP files, JavaScript/CSS/image assets, `config.php` | Kubernetes RWX volume mount | **No** |
| ㉑ | Nextcloud Management | PostgreSQL Cluster `POSTGRES_PORT` (default: 5432) | Initialise the database schema on first install; run schema migrations and post-update optimisations  | Application and user-generated data | `DATABASE_TYPE` wire protocol over TCP port `POSTGRES_PORT` | **Optional** ⚠️ — TLS enabled by setting `NEXTCLOUD_TRUSTED_CERTIFICATES.POSTGRES: "yes"` (for PostgreSQL) or `NEXTCLOUD_TRUSTED_CERTIFICATES.MYSQL: "yes"` (for MySQL/MariaDB); supply a custom CA via `NEXTCLOUD_TRUSTED_CERTIFICATES`  |
| ㉒ | Nextcloud Management | Redis / Redis Cluster `REDIS_PORT` (default: 6379), or `REDIS_PORT_*` (for Redis Cluster)  | Flush stale cache and configure Redis after a Nextcloud version update | Configuration commands; cache seed data | Redis RESP protocol over TCP port `REDIS_PORT` or `REDIS_PORT_*` | **Optional** ⚠️ — TLS enabled by setting `NEXTCLOUD_TRUSTED_CERTIFICATES.REDIS: "yes"`; supply a custom CA via `NEXTCLOUD_TRUSTED_CERTIFICATES`  |
| ㉔ | Notify-Push | Nextcloud Management `:9001` | Pod status check | None | TCP | **No** — cluster-internal |
| ㉕ | Notify-Push | Redis / Redis Cluster `REDIS_PORT` (default: 6379), or `REDIS_PORT_*` (for Redis Cluster) | Subscribe to file-change events published by Nextcloud so they can be forwarded as push notifications to clients | File-change event messages | Redis RESP over TCP | **Optional** ⚠️ — TLS enabled by setting `NEXTCLOUD_TRUSTED_CERTIFICATES.REDIS: "yes"`; supply a custom CA via `NEXTCLOUD_TRUSTED_CERTIFICATES` |
| ㉖ | Whiteboard | Redis / Redis Cluster `REDIS_PORT` (default: 6379); ⚠️ note: Whiteboard does not support `REDIS_MODE: rediscluster` or `REDIS_PREFIX` | Persist the collaborative whiteboard canvas state across reconnects and pod restarts | Application data and session tokens | Redis RESP protocol over TCP | **No** — currently not supported |
| ㉗ | Whiteboard | Nginx Ingress Controller `NC_DOMAIN:443` | Fetch and save content data | File metadata and document content | HTTPS | **Yes** — TLS |
| ㉘ | Collabora Online | Nginx Ingress Controller `NC_DOMAIN:443` | Fetch and save content data | File metadata and document content | HTTPS | **Yes** — TLS |
| ㉙ | OnlyOffice Document Server | Nginx Ingress Controller `NC_DOMAIN:443` | Fetch and save content data | File metadata and document content | HTTPS | **Yes** — TLS |
| ㉚ | Talk HPB | Nginx Ingress Controller `NC_DOMAIN:443` | Authenticate signaling participants and retrieve room and backend configuration from the Nextcloud Talk API | Shared-secret auth tokens, Nextcloud Talk room metadata, signaling backend configuration | HTTPS | **Yes** — TLS |
| ㉛ | Talk-Recording | Nginx Ingress Controller `TALK_HOST:443` | Send internal recording control commands (start, pause, stop, status query) to the HPB | Recording session control messages, internal shared secret | HTTPS | **Yes** — TLS |
| ㉜ | Talk-Recording | Nginx Ingress Controller `NC_DOMAIN:443` | Upload the completed call recording to Nextcloud | Recording file content | HTTPS | **Yes** — TLS |
| ㉝ | Internet | Nginx Ingress Controller `ONLYOFFICE_HOST:443` | Entry point for browser-side OnlyOffice editor access on its dedicated domain | HTTPS requests, WebSocket editor messages, document assets | HTTPS | **Yes** — TLS |

> Egress connections (E-1 … E-11) are detailed in **[§ 3 — Egress Connections (both modes)](#3-egress-connections--both-modes)** below.

---

## 3. Egress Connections — Both Modes

Both deployment modes (non-scalable and scalable) initiate the same egress connections from the same containers. The per-mode connection detail tables use different numbering for internal connections, so egress numbers differ between modes; this section uses stable labels **E-1 … E-11** independent of deployment mode.

All egress from Nextcloud and Nextcloud Management can be routed through `HTTP_PROXY` / `PROXY_EXCLUDE` (`values.yaml`).

[![Diagram of egress services](./Architecture%20Communication%20Diagrams%20egress.svg "Click to open image for zooming")](./Architecture%20Communication%20Diagrams%20egress.svg)

### Egress Connection Details

| # | From | To | Why | Data Transferred | Protocol | Encrypted |
|---|------|----|-----|------------------|----------|-----------|
| E-1 | Nextcloud / Nextcloud Management via `cron.php` (background sync) | `lookup.nextcloud.com` | Register this instance in the federated sharing directory; resolve remote user addresses during share creation | Server registration payload (instance URL, public key); remote user lookup queries and responses | HTTPS over TCP `:443` | **Yes** — TLS; disabled when `AIRGAPPED: "yes"` |
| E-2 | Nextcloud / Nextcloud Management via `cron.php` (background registration) | `push-notifications.nextcloud.com` | Register mobile push subscriptions and relay push events to APNs / FCM | Device push token registrations; outgoing push notification events | HTTPS over TCP `:443` | **Yes** — TLS; disabled when `AIRGAPPED: "yes"` |
| E-3 | Nextcloud Management via `cron.php` exclusively | `cloud.nextcloud.com` | The `support` app validates `SUBSCRIPTION_KEY` as a background job only — never triggered by web requests | Subscription key and instance URL; validation response | HTTPS over TCP `:443` | **Yes** — TLS; skipped when `AIRGAPPED: "yes"` or `SUBSCRIPTION_KEY` is empty |
| E-4 | Nextcloud / Nextcloud Management | `download.nextcloud.com` / `apps.nextcloud.com` / `github.com` | Download Enterprise ZIP on install/upgrade; download app packages | ZIP archives; app packages; JSON manifests | HTTPS over TCP `:443` | **Yes** — TLS; disabled when `AIRGAPPED: "yes"` or `NEXTCLOUD_APP_STORE_URL: "no"` |
| E-5 | ClamAV | `database.clamav.net` | `freshclam` downloads updated virus signature databases every ~2 hours | Compressed signature database files (`.cvd` / `.cld`); version metadata | HTTPS over TCP `:443` | **Yes** — TLS |
| E-6 | Nextcloud / Nextcloud Management via `cron.php` (digest and queued mail) | SMTP Server | Nextcloud sends transactional emails; Nextcloud Management sends notification digests and activity summaries | Emails, SMTP credentials | SMTP/SMTPS/STARTTLS over `SMTP_PORT` | **Optional** ⚠️ — `SMTP_SECURE: ssl` or `tls`; custom CA via `NEXTCLOUD_TRUSTED_CERTIFICATES.MAILER: "yes"` |
| E-7 | Nextcloud / Nextcloud Management via `cron.php` (`ldap:sync`) | LDAP / Active Directory | On-demand LDAP auth on login; periodic user/group sync | LDAP bind DN + password; search queries; attribute data | LDAP `:389` or LDAPS `:636` (configurable via Nextcloud admin settings) | **Optional** ⚠️ — configurable via Nextcloud admin settings; `LDAPTLS_CACERT` auto-set from `NEXTCLOUD_TRUSTED_CERTIFICATES` |
| E-8 | Nextcloud (Mail app UI) / Nextcloud Management via `cron.php` (Mail background sync) | IMAP Server | Interactive mailbox browsing; periodic message sync; IMAP-based external storage | IMAP commands and email data | IMAP `:143` or IMAPS `:993` (configurable via Nextcloud web UI) | **Optional** ⚠️ — configurable via Nextcloud web UI |
| E-9 | Nextcloud | SAML / OIDC Identity Provider | The `user_saml` app authenticates users via SSO | SAML AuthnRequest/Response; OIDC authorisation code, ID token, access token | HTTPS over `:443` | **Yes** — TLS, configurable via Nextcloud admin settings |
| E-10 | Nextcloud / Nextcloud Management | External Storage (user-configured) | Mount remote file shares via `files_external` app | File content, directory listings, metadata; auth credentials | SMB/CIFS `:445`; SFTP `:22`; FTP/FTPS `:21`; WebDAV `:80`/`:443` | **Optional** ⚠️ — depends on protocol |
| E-11 | Nextcloud / Nextcloud Management | External AI Provider | User or `taskprocessing:worker` processes execute AI tasks (Assistant, Smart Picker) | Task input (prompts, document content); results; API credentials | HTTPS over `:443` | **Optional** ⚠️ — depends on provider |
