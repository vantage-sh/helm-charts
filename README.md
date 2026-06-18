[![Release Charts](https://github.com/vantage-sh/helm-charts/actions/workflows/release.yml/badge.svg?branch=main)](https://github.com/vantage-sh/helm-charts/actions/workflows/release.yml)

# Vantage Helm Charts

This repo contains Vantage Helm Charts, including the Helm Chart for the Vantage Kubernetes agent.

## Vantage Kubernetes Agent

The Vantage Kubernetes agent offers a single in-cluster deployment that handles both metrics collection and upload to Vantage without any intermediary requirements. The Vantage Kubernetes agent requires connectivity to the cluster’s `kube-apiserver`, the `kubelet` resources endpoint (generally, port 10250 on a `kubelet`), the Vantage API, and S3 in the `us-east-1` region. 

![Vantage Kubernetes agent architecture](https://assets.vantage.sh/blog/announcing-the-official-kubernetes-integration/vantage-kubernetes-agent.png)

## Usage

[Helm](https://helm.sh) must be installed to use the charts. See Helm's [documentation](https://helm.sh/docs) to get started.

Once Helm has been set up correctly, add the repo as follows:

    helm repo add vantage https://vantage-sh.github.io/helm-charts

If you previously added this repo, run `helm repo update` to retrieve the latest versions of the packages. Then, run `helm search repo vantage` to see the charts.

To install the `vantage-kubernetes-agent` chart, run the following command:

    helm upgrade -n vantage vka vantage/vantage-kubernetes-agent --install --set agent.token=$VANTAGE_API_TOKEN,agent.clusterID=$CLUSTER_ID --create-namespace

To uninstall the chart, run the following command:

    helm delete vantage-kubernetes-agent
    
See the [Vantage Kubernetes agent product documentation](https://docs.vantage.sh/kubernetes_agent) for additional details about the agent and its functionality.

## Network cost collection (optional)

Set `agent.networkCost.enabled=true` to deploy the per-node `vantage-network-collector`
DaemonSet alongside the agent. The collector reads conntrack or its own eBPF accounting
program on each node to attribute pod network traffic to billing buckets (in-zone,
in-region, cross-region, internet), and the agent pulls per-pod byte summaries from it
each report cycle. When `enabled=false` (the default) none of these resources are rendered.

### Conntrack byte accounting (conntrack source)

The collector bills on per-flow byte counters from the kernel conntrack table. Those
counters stay at zero unless **`net.netfilter.nf_conntrack_acct=1`** is set on every
node ([kernel docs](https://www.kernel.org/doc/html/latest/networking/nf_conntrack-sysctl.html)).
Many node images ship with this disabled by default. Without it the collector sees flows
but reports zero bytes, so no pod network costs are attributed.

Enable it cluster-wide **before** generating traffic — the kernel only counts bytes on
connections opened *after* accounting is turned on. Verify on a node:

    sysctl net.netfilter.nf_conntrack_acct   # should print 1

To make it persistent across reboots, add a host sysctl drop-in (exact path varies by OS):

    echo 'net.netfilter.nf_conntrack_acct=1' | sudo tee /etc/sysctl.d/99-vantage-conntrack-acct.conf
    sudo sysctl --system

On managed node groups that do not expose bootstrap hooks (for example EKS AL2023 managed
node groups), apply the setting with a small privileged tuning DaemonSet or your platform's
node-configuration mechanism. The chart does not set this sysctl for you.

### Flow data source (conntrack or eBPF)

`agent.networkCost.source` defaults to `conntrack`. On clusters where the CNI datapath
bypasses kernel netfilter (for example, Cilium with kube-proxy replacement), set
`agent.networkCost.source=ebpf` to use the collector's cgroup eBPF accounting program
instead.

The eBPF source does not require `net.netfilter.nf_conntrack_acct=1`. It does require a
node kernel >= 5.8 with BTF and cgroup v2. When `source: ebpf`, the chart mounts the host
cgroup root (`agent.networkCost.cgroupRoot`, default `/sys/fs/cgroup`) and grants the
collector `CAP_BPF`, `CAP_PERFMON`, and `CAP_NET_ADMIN`.

Traffic is classified by matching each flow's remote IP against a customer-provided
CIDR -> zone/region map supplied via `agent.networkCost.subnets`. CIDRs are matched
within the same IP family, so on dual-stack / IPv6 clusters you must include your IPv6
pod, service, and VPC ranges or that traffic falls through to the `internet` bucket.

```yaml
agent:
  networkCost:
    enabled: true
    # port: 9012                     # collector listen + agent dial port (default 9012)
    # source: "conntrack"            # use "ebpf" on clusters bypassing kernel conntrack
    # cgroupRoot: "/sys/fs/cgroup"   # only used when source is "ebpf"
    # ebpfDebug: false               # only used when source is "ebpf"
    subnets:
      - cidr: "10.0.0.0/16"
        region: "us-east-1"
        zone: "us-east-1a"
      - cidr: "2600:1f18:abcd::/56"  # IPv6 / dual-stack clusters
        region: "us-east-1"
    # overrides:                     # optional CIDR -> bucket forcing list
    #   - cidr: "203.0.113.0/24"
    #     bucket: "internet"
    # existingConfigMap: ""          # BYO ConfigMap with subnets.yaml instead of inline subnets
```

### Scheduling on tainted nodes

The collector is a DaemonSet, so it tries to run on every node. Kubernetes will
**not** schedule it onto nodes that carry custom taints unless the collector pod
has a matching toleration. If some of your nodes are tainted (a common setup for
dedicated, GPU, or system node pools), the collector skips them and you get no
network cost data for the pods running there.

It is up to you to decide which nodes the collector should run on. Use
`agent.networkCost.tolerations` to allow it onto tainted nodes, and
`agent.networkCost.nodeSelector` / `agent.networkCost.affinity` to constrain it
to (or away from) specific nodes. These apply only to the collector DaemonSet
and are independent of the top-level `tolerations` / `nodeSelector` / `affinity`
used by the agent workload.

```yaml
agent:
  networkCost:
    enabled: true
    tolerations:
      - key: "dedicated"
        operator: "Equal"
        value: "gpu"
        effect: "NoSchedule"
    # nodeSelector:                  # only run the collector on matching nodes
    #   kubernetes.io/os: linux
    # affinity: {}                   # standard pod affinity/anti-affinity rules
    subnets:
      - cidr: "10.0.0.0/16"
        region: "us-east-1"
```

### Discovering subnet CIDRs

- **AWS**: VPC CIDRs `aws ec2 describe-vpcs --query 'Vpcs[].{v4:CidrBlock,v6:Ipv6CidrBlockAssociationSet[0].Ipv6CidrBlock}'`; per-AZ subnets `aws ec2 describe-subnets --query 'Subnets[].{cidr:CidrBlock,az:AvailabilityZone}'`.
- **GCP**: `gcloud compute networks subnets list --format='table(name,region,ipCidrRange,ipv6CidrRange)'`.
- **Azure**: `az network vnet subnet list --resource-group <rg> --vnet-name <vnet> --query '[].{name:name,prefixes:addressPrefixes}'`.

Map each subnet's CIDR to the AWS/GCP zone (or region) it lives in so cross-AZ traffic
is billed as `in_zone` / `in_region` rather than `cross_region` or `internet`.

## Issues

If you encounter any issues with the Helm Charts, please open a GitHub issue.
