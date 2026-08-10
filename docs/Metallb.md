# Enterprise-AIO with Metallb
In certain cases, network restrictions may prevent the installation of a load balancer in front of the cluster. In other scenarios, where no hardware load balancers are available, there may be a need to assign an IP address to a Service of type **LoadBalancer**. One option is to install a virtual load balancer such as Metallb within the cluster. For more information about Metallb, see the [Metallb FAQ](https://metallb.io/faq/)

Once you have completed the installation of Metallb on your cluster you should see an IP addresses allocated to the **LoadBalancer** service type. These will be used to map ingress to your cluster.

#### Process steps

1. A configured k8s/openshift cluster
1. Helm installed
1. Install Metallb
1. Edit kubeproxy configmap
1. Create IPAddressPool
1. Configure L2 Advertisement
1. Check if LoadBalancer types have been assigened IP's

## Details
--- PREVIEW ---

#### Install Metallb
```
helm repo add metallb https://metallb.github.io/metallb
helm install metallb metallb/metallb --namespace metallb-system --create-namespace
```

#### Edit kubeproxy configmap
In the next steps you configure the kubeproxy to allow linux kernel load balancer (IPVS) and strict arp for address broadcast.
```
kubectl edit configmap -n kube-system kube-proxy
```
Update the following vales
```
mode: "ipvs"
ipvs:
    strictARP: true
```

#### Create IPAddressPool
In the next steps you create a yaml file to make available an IP address from the configured pool. Metallb will assign IP's to services using this address range. (metallb-ips.yaml) 
```
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
    name: default-pool
    namespace: metallb-system
spec:
    addresses:
    - 192.168.XXX.150-192.168.XXX.170

```
You can use this command to apply the change to your cluster
```
kubectl apply -f metallb-ips.yaml
```

#### Configure L2 Advertisement
In the next steps you create a yaml file to enable the L2 advertisement. (metallb-l2.yaml) 
```
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
    name: default
    namespace: metallb-system  

```
You can use this command to apply the change to your cluster
```
kubectl apply -f metallb-l2.yaml
```

#### Check if LoadBalancer types have been assigened IP's
Once you have successfully completed these steps and you restart your deployment you should see that metallb has assigned ip addresses that then should be fonfigured on your network to allow ingress.

