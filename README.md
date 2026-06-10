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
DaemonSet alongside the agent. The collector reads conntrack on each node to attribute
pod network traffic to billing buckets (in-zone, in-region, cross-region, internet), and
the agent pulls per-pod byte summaries from it each report cycle. When `enabled=false`
(the default) none of these resources are rendered.

Traffic is classified by matching each flow's remote IP against a customer-provided
CIDR -> zone/region map supplied via `agent.networkCost.subnets`. CIDRs are matched
within the same IP family, so on dual-stack / IPv6 clusters you must include your IPv6
pod, service, and VPC ranges or that traffic falls through to the `internet` bucket.

```yaml
agent:
  networkCost:
    enabled: true
    # port: 9012                     # collector listen + agent dial port (default 9012)
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

### Discovering subnet CIDRs

- **AWS**: VPC CIDRs `aws ec2 describe-vpcs --query 'Vpcs[].{v4:CidrBlock,v6:Ipv6CidrBlockAssociationSet[0].Ipv6CidrBlock}'`; per-AZ subnets `aws ec2 describe-subnets --query 'Subnets[].{cidr:CidrBlock,az:AvailabilityZone}'`.
- **GCP**: `gcloud compute networks subnets list --format='table(name,region,ipCidrRange,ipv6CidrRange)'`.
- **Azure**: `az network vnet subnet list --resource-group <rg> --vnet-name <vnet> --query '[].{name:name,prefixes:addressPrefixes}'`.

Map each subnet's CIDR to the AWS/GCP zone (or region) it lives in so cross-AZ traffic
is billed as `in_zone` / `in_region` rather than `cross_region` or `internet`.

## Issues

If you encounter any issues with the Helm Charts, please open a GitHub issue.
