## Usage

[Helm](https://helm.sh) must be installed to use the charts.  Please refer to
Helm's [documentation](https://helm.sh/docs) to get started.

## Prerequisites

Before you begin, ensure you have the following installed:

1. **CNPG**: [CloudNativePG](https://cloudnative-pg.io/) - A PostgreSQL operator for Kubernetes.
   - Installation guide: [CloudNativePG Installation](https://cloudnative-pg.io/docs/current/quickstart/)

2. **Traefik**: A reverse proxy and load balancer for Kubernetes.
   - Installation guide: [Traefik Installation](https://doc.traefik.io/traefik/getting-started/install-traefik/)

3. **Cert-Manager**: A Kubernetes add-on to automate the management and issuance of TLS certificates.
   - Installation guide: [Cert-Manager Installation](https://cert-manager.io/docs/installation/kubernetes/)

Make sure all these components are up and running in your Kubernetes cluster before proceeding.


Once Helm has been set up correctly, add the repo as follows:

```bash
helm repo add dou-charts https://spartan-dou.github.io/helm-charts
```

If you had already added this repo earlier, run `helm repo update` to retrieve
the latest versions of the packages.  You can then run `helm search repo
dou-charts` to see the charts.

To install the <chart-name> chart:

```bash
helm install my-<chart-name> dou-charts/<chart-name>
```

To uninstall the chart:

```bash
helm delete my-<chart-name>
```
