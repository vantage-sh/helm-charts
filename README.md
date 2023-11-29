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

## Issues

If you encounter any issues with the Helm Charts, please open a GitHub issue.
