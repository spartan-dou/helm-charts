## Usage

[Helm](https://helm.sh) must be installed to use the charts.  Please refer to
Helm's [documentation](https://helm.sh/docs) to get started.
[CloudNativePG](https://github.com/cloudnative-pg/cloudnative-pg), [Traefik](https://github.com/traefik/traefik) and [cert-manager](https://github.com/cert-manager/cert-manager) must be installed.

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

![Helm Unit Tests](https://github.com/spartan-dou/helm-charts/actions/workflows/helm-tests.yaml/badge.svg)
