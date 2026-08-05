# helm-charts

🇫🇷 [Version française](README.md)

Personal Helm charts by `spartan-dou`, packaged and published via `chart-releaser` on GitHub Pages.

## Table of contents

- [Installation](#installation)
- [Chart `commons`](#chart-commons)
  - [Overview](#overview)
  - [`secrets` (references to existing Secrets)](#secrets-references-to-existing-secrets)
  - [`global`](#global)
  - [A `component`](#a-component)
    - [`deployment`](#deployment)
    - [Environment variables and `commons.getValue`](#environment-variables-and-commonsgetvalue)
    - [Probes](#probes)
    - [`volumes`](#volumes)
    - [`service`](#service)
    - [`ingress`](#ingress)
    - [`secrets`](#secrets)
    - [`cronjobs`](#cronjobs)
    - [`postgres` (embedded database on a component)](#postgres-embedded-database-on-a-component)
  - [RBAC](#rbac)
  - [Addons](#addons)
    - [`addons.vscode`](#addonsvscode)
    - [`addons.redis`](#addonsredis)
    - [`addons.pgadmin`](#addonspgadmin)
    - [`addons.postgres`](#addonspostgres)
  - [Resource naming](#resource-naming)
  - [Values validation](#values-validation)
  - [Tests](#tests)

## Installation

[Helm](https://helm.sh) must be installed. [CloudNativePG](https://github.com/cloudnative-pg/cloudnative-pg), [Traefik](https://github.com/traefik/traefik) and [cert-manager](https://github.com/cert-manager/cert-manager) must be installed on the target cluster (CloudNativePG only if you use the `postgres` features).

```bash
helm repo add dou-charts https://spartan-dou.github.io/helm-charts
helm repo update
helm search repo dou-charts
```

Install a chart:

```bash
helm install my-<chart-name> dou-charts/<chart-name>
```

Uninstall:

```bash
helm delete my-<chart-name>
```

![Helm Unit Tests](https://github.com/spartan-dou/helm-charts/actions/workflows/helm-tests.yml/badge.svg)

## Chart `commons`

### Overview

`commons` is a generic, "à la carte" chart: instead of defining a `Deployment`/`Service`/`Ingress` per application, each application is described as an object in the `components` list, and the chart generates all the corresponding Kubernetes resources. It also provides ready-to-use **addons** (VS Code, Redis, pgAdmin, PostgreSQL via CloudNativePG) that any `component` can consume.

A single release can therefore carry several independent applications (several `Deployment`, `Service`, `Ingress`, etc.), all prefixed with the release name.

Minimal example:

```yaml
components:
  - name: nginx
    deployment:
      containers:
        - image:
            repository: nginx
            tag: "1.27"
    service:
      ports:
        - name: http
          port: 80
```

See `charts/commons/tests/values/values.yaml` for a complete example covering nearly every feature described below (it also serves as the fixture for the `helm-unittest` tests).

### `secrets` (references to existing Secrets)

Optional root section: a table of **aliases** pointing at Kubernetes Secrets that **already exist in the namespace** (SealedSecret, ExternalSecret, `kubectl create secret`, a Vault operator…). The chart never carries the value, only the reference.

```yaml
secrets:
  pg:
    existingSecret: app-pg-credentials   # kubernetes.io/basic-auth Secret
  redis:
    existingSecret: app-redis
    key: redis-password                  # defaults to `password`
  apiKey:
    existingSecret: app-third-party
    key: api-token
```

Direct consequence: **no sensitive data goes through Helm**. `helm get values <release>`, the release Secret and a `helm template` only reveal Secret *names*. Rotating a password happens in the cluster, without touching the values or redeploying the chart.

In exchange, the referenced Secrets must **exist before installation**: otherwise pods stay in `CreateContainerConfigError` and the CloudNativePG cluster never bootstraps.

#### Consumption

| Location | Key | Example |
|---|---|---|
| Environment variable | `env[].secretRef` | `- name: API_KEY` / `secretRef: apiKey` |
| Postgres (component or addon) | `cluster.secretRef` | replaces `cluster.password` |
| Redis | `addons.redis.passwordSecretRef` | replaces `addons.redis.password` |
| pgAdmin | `addons.pgadmin.auth.passwordSecretRef` | replaces `addons.pgadmin.auth.password` |
| Any value | `__secrets__<alias>__name` / `__secrets__<alias>__key` | name / key of the referenced Secret |

The `secretRef` shorthand on an environment variable produces a full `valueFrom.secretKeyRef`:

```yaml
env:
  - name: API_KEY
    secretRef: apiKey        # -> secretKeyRef { name: app-third-party, key: api-token }
```

It is available in `deployment`, `cronjobs` and `job`, on containers as well as initContainers.

#### Postgres

`cluster.secretRef` replaces `cluster.password`: the chart **no longer generates** the `<release>-postgres-secret` Secret and points `bootstrap.initdb.secret` at the referenced one. That Secret must be of type `kubernetes.io/basic-auth`, with the `username` and `password` keys (a CloudNativePG constraint — the alias `key` field is therefore ignored here).

`cluster.username` is still required in plain text: CloudNativePG needs it as the cluster `owner`, and it is not sensitive data.

The `__<source>__postgres__password_secret` placeholder automatically resolves to the external Secret. `__<source>__postgres__password`, on the other hand, **fails explicitly**: the password exists nowhere on the Helm side. Use a `secretKeyRef` instead:

```yaml
env:
  - name: POSTGRES_PASSWORD
    valueFrom:
      secretKeyRef:
        name: __components__postgres__password_secret
        key: password
```

#### pgAdmin

The `pgpass` file is no longer rendered into a ConfigMap. It is rebuilt at pod startup by a `render-pgpass` initContainer, which receives the passwords through `secretKeyRef` and writes the file with mode `0600` into an `emptyDir` volume shared with pgAdmin.

This change also applies to the **legacy mode** (plain-text password in the values): the pgpass is now built from the Secret generated by the chart, instead of being copied in plain text into a ConfigMap.

#### Limitations

- Secrets must pre-exist — the chart does not create them and cannot check their content at render time. A key missing from the Secret only shows up when the pod starts.
- An unknown alias, or a missing `existingSecret`, makes the rendering **fail** with an explicit message.
- Alias names cannot contain `__` (the placeholder separator); the values schema rejects them.
- `components[].secrets[]` still generates Secrets from the values: that section stays reserved for **non-sensitive** data. For anything sensitive, reference an external Secret.

### `global`

| Key | Default | Description |
|---|---|---|
| `global.timezone` | `Europe/Paris` | Injected as the `TZ` env var in **every** container/initContainer (deployment, cronjob, job), and used as `postgresql.parameters.timezone` on CloudNativePG clusters. |
| `global.securityContext` | `{}` | Default pod `securityContext`, merged (`mergeOverwrite`) with the `securityContext` specific to each `deployment`/`cronjob` (keys defined at the component level take precedence). Accepts any valid Kubernetes field (`runAsUser`, `runAsGroup`, `fsGroup`, `supplementalGroups`, …). |
| `global.pvc.storage.size` | `1Gi` | Default PVC size when `storage.size` isn't set on the volume. |
| `global.pvc.storage.storageClassName` | `""` | Default PVC storage class. |
| `global.pvc.storage.accessMode` | `ReadWriteOnce` | Default PVC access mode. |
| `global.rbac.enabled` | `false` | See [RBAC](#rbac). |
| `global.rbac.serviceAccountName` | — | Required if `rbac.enabled: true`. |
| `global.rbac.clusterRoleName` | — | Required if `rbac.enabled: true`. |
| `global.rbac.rules` | — | List of `PolicyRule` (standard Kubernetes RBAC format) for the `ClusterRole`. |
| `global.var` | `{}` | Free-form key/value store, accessible from any `env[].value` via `__global__<key>` (see [`commons.getValue`](#environment-variables-and-commonsgetvalue)). |
| `global.ingress.className` | `traefik` | Default `ingressClassName` for any `ingress` (component or addon, including `addons.pgadmin.ingress`) that doesn't explicitly set its own `className`. |

### A `component`

Each entry in the `components` list accepts:

| Key | Description |
|---|---|
| `name` | Logical name of the component. Used to build resource names ([see below](#resource-naming)) and the default name of the first container. |
| `appNameOverride` | Overrides the `app.kubernetes.io/name` label independently of `name`. |
| `deployment` | See [`deployment`](#deployment). |
| `service` | See [`service`](#service). |
| `ingress` | See [`ingress`](#ingress). |
| `secrets` | See [`secrets`](#secrets). |
| `cronjobs` | See [`cronjobs`](#cronjobs). |
| `postgres` | See [`postgres`](#postgres-embedded-database-on-a-component). |

#### `deployment`

| Key | Default | Description |
|---|---|---|
| `replicas` | `1` | |
| `strategy.type` | `RollingUpdate` | |
| `securityContext` | — | Merged with `global.securityContext`. |
| `nodeSelector` | — | |
| `hostNetwork` | — | |
| `resourceClaims[]` | — | DRA resources, at the pod level. Passed through as-is. See [DRA](#dynamic-resource-allocation-dra). |
| `initContainers[]` | — | `name` (defaults to the component name), `image.repository`, `image.tag` (default `latest`), `securityContext`, `command`, `args`, `env[]`, `volumeMounts[]`. |
| `containers[]` | — | See below. |
| `volumes[]` | — | See [`volumes`](#volumes). |

Each entry in `containers[]`:

- `name` (defaults to the component name)
- `image.repository`, `image.tag` (default `latest`)
- `command`, `args`
- `securityContext`
- `env[]` (see [below](#environment-variables-and-commonsgetvalue))
- `lifecycle` (passed through as-is)
- `volumeMounts[]` (`name`, `mountPath`, optional `subPath`)
- `additionalsPorts[]` (`name`, `containerPort`, `protocol` default `TCP`, optional `hostPort`) — *(field name exactly as-is in the chart, with the trailing "s")*
- `livenessProbe` / `readinessProbe` / `startupProbe` / `probe` — see [Probes](#probes)
- `resources` (passed through as-is, including `claims` — see [DRA](#dynamic-resource-allocation-dra))

> If `service.ports` is set on the component, its ports are automatically added to the `ports` section of the **first** container in the list only (in addition to its own `additionalsPorts`, if any). Other containers only get their own `additionalsPorts`, if they define any.

A `checksum/<volume-name>` annotation is automatically added to the pod for every chart-generated `configMap` volume (not `useExisting` ones) that has `data`, to trigger a rollout whenever the ConfigMap's content changes.

#### Dynamic Resource Allocation (DRA)

[DRA](https://kubernetes.io/docs/concepts/scheduling-eviction/dynamic-resource-allocation/) is GA as of Kubernetes 1.34 (`resource.k8s.io/v1`). For accelerators (GPUs, TPUs…) it replaces the device plugin model: instead of counting a whole resource (`limits: {nvidia.com/gpu: 1}`), the pod references a `ResourceClaim` that **the scheduler allocates before placing the pod**.

The practical consequence: an unavailable resource leaves the pod `Pending` and retried, whereas a device plugin that has not registered yet produced a terminal `UnexpectedAdmissionError` — typically after a node reboot.

Two blocks, at two levels, and both are required:

```yaml
components:
  - name: inference
    deployment:
      # 1. Pod level: which claims, and what produces them.
      resourceClaims:
        - name: gpu
          resourceClaimTemplateName: single-gpu   # or resourceClaimName for an existing claim
      containers:
        - name: server
          image:
            repository: ollama/ollama
            tag: latest
          resources:
            requests: {cpu: 400m, memory: 4Gi}
            limits: {cpu: 3000m, memory: 32Gi}
            # 2. Container level: which of the pod's claims it consumes.
            claims:
              - name: gpu
```

Several containers in the same pod may reference the same claim: that is DRA's sharing model, where the device plugin required a whole resource per container.

The chart only copies both blocks through. The `ResourceClaimTemplate` (or `ResourceClaim`) and the `DeviceClass` it targets must be created alongside, usually by the vendor's driver.

> The expected shape is the Kubernetes 1.31+ one, with `resourceClaimName` / `resourceClaimTemplateName` at the root of the entry. The nested `source` block from earlier versions is deprecated.

#### Environment variables and `commons.getValue`

Every `env[].value` and `env[].valueFrom.secretKeyRef.name` value goes through the `commons.getValue` helper. A "normal" value (e.g. `prod`) is returned as-is. A value in the `__<source>__<type>__<field>` format is resolved dynamically:

| Format | Resolves to |
|---|---|
| `__addons__postgres__host` | Host of the **shared** CloudNativePG cluster (`addons.postgres`): `<release>-postgres-rw` |
| `__addons__postgres__username` / `__password__` / `__database__` | `addons.postgres.cluster.username` / `.password` / `.database` (default `app`) |
| `__addons__postgres__password_secret` | Name of the `<release>-postgres-secret` Secret, or of the external Secret if `cluster.secretRef` |
| `__components__postgres__host` / `__username__` / `__password__` / `__database__` / `__password_secret__` | Same, but for the CloudNativePG cluster **embedded in the current component** (`component.postgres.*`) |
| `__addons__redis__host` / `__addons__redis__port` | Host / port of the shared Redis service (`addons.redis`) |
| `__addons__redis__password` | `addons.redis.password` in plain text — **fails** if `passwordSecretRef` is used |
| `__addons__redis__password_secret` / `__password_secret_key__` | Name / key of the Secret holding the Redis password (the external one if `passwordSecretRef`) |
| `__<component-name>__pvc__<pvc-name>` | Full Kubernetes name of the PVC `<pvc-name>` defined on the component `<component-name>` (e.g. `__nginx__pvc__data-2-pvc`) |
| `__components__pvc__<pvc-name>` | Same, but on the current component |
| `__<name>__configmap__<name>` / `__<name>__service__<name>` / `__<name>__secret__<name>` | Same principle for a ConfigMap, a Service, or a Secret |
| `__global__<key>` | `global.var.<key>` |
| `__secrets__<alias>__name` / `__secrets__<alias>__key` | Name / key of the existing Secret designated by the alias — see [`secrets`](#secrets-references-to-existing-secrets) |

Example (from the tests):

```yaml
env:
  - name: POSTGRES_USERNAME
    value: __components__postgres__username
  - name: POSTGRES_PASSWORD
    valueFrom:
      secretKeyRef:
        name: __components__postgres__password_secret
        key: password
```

#### Probes

`probe` defines a shared configuration used as the default for `livenessProbe`, `readinessProbe` and `startupProbe` when these aren't individually defined. Each one accepts `tcpSocket`, `exec` or `httpGet` (`path` default `/`, `port` default `http`), plus:

| Probe | `initialDelaySeconds` | `periodSeconds` | `timeoutSeconds` | `failureThreshold` |
|---|---|---|---|---|
| `livenessProbe` | 10 | 10 | 2 | 3 |
| `readinessProbe` | 5 | 5 | 2 | 3 |
| `startupProbe` | 0 | 5 | 2 | 30 |

#### `volumes`

Each entry in `deployment.volumes[]` (and `cronjobs[].initContainers[]/containers[]` volumes) is one of the following three cases:

- **Chart-generated ConfigMap**:
  ```yaml
  - name: config
    configMap:
      data:
        config.yaml: "key: value"
  ```
  Generates a `ConfigMap` object (see `templates/configmap.yaml`). Add `defaultMode` / `readOnly` as needed.

- **Already-existing ConfigMap in the cluster**:
  ```yaml
  - name: config
    configMap:
      useExisting: true
      name: my-existing-configmap
  ```

- **Chart-generated PVC**:
  ```yaml
  - name: data
    pvc:
      name: data-pvc
      storage:
        size: 5Gi
        storageClassName: local-path
        accessMode: ReadWriteOnce
  ```
  Generates a `PersistentVolumeClaim` object (see `templates/pvc.yaml`), falling back to `global.pvc.storage.*` for unset fields. `storage.volumeMode` and `storage.selector` are also supported.

- **Already-existing PVC**: `pvc.useExisting: true` + `pvc.name`.

- **Raw Kubernetes volume**: any entry with neither `configMap` nor `pvc` set — passed through as-is (`toYaml`) into `volumes:`, which lets you use any Kubernetes volume type not covered above (`emptyDir`, `secret`, `hostPath`, …).

#### `service`

| Key | Default | Description |
|---|---|---|
| `type` | `ClusterIP` | |
| `annotations` | — | |
| `ports[].name` | — | |
| `ports[].port` | — | |
| `ports[].targetPort` | = `port` | |
| `ports[].protocol` | — | |
| `ports[].nodePort` | — | Only used if `type: NodePort`. |

#### `ingress`

| Key | Default | Description |
|---|---|---|
| `enabled` | `false` | |
| `className` | `global.ingress.className` | |
| `annotations` | — | |
| `hosts[].host` | — | |
| `hosts[].paths[].path` | `/` | |
| `hosts[].paths[].pathType` | `Prefix` | |
| `hosts[].paths[].name` | Component's Service | Name of the backend Service; defaults to the one generated for the current component. |
| `hosts[].paths[].port` | `80` | Backend Service port: an integer is rendered as `port.number`, a string as `port.name` (named port). |
| `tls[]` | — | Passed through as-is (`toYaml`), standard `spec.tls` format of an Ingress. |

#### `secrets`

List of `Opaque` Secrets (or another `type`) attached to the component:

```yaml
secrets:
  - name: my-secret
    data:
      key: value   # automatically base64-encoded
    type: Opaque    # default
```

#### `cronjobs`

Each entry generates a `CronJob`. If `runOnStartup: true` **and** `enabled: true`, a `Job` (`ttlSecondsAfterFinished: 60`) is **additionally** created with the same spec, to run the task immediately at deploy time.

| Key | Default | Description |
|---|---|---|
| `enabled` | — | Must be `true` for the CronJob to be rendered. |
| `schedule` | — | Required. |
| `runOnStartup` | `false` | See above. |
| `concurrencyPolicy` | — | |
| `startingDeadlineSeconds` | — | |
| `successfulJobsHistoryLimit` | `5` | |
| `failedJobsHistoryLimit` | `5` | |
| `suspend` | — | |
| `restartPolicy` | `Never` | |
| `securityContext`, `nodeSelector` | — | |
| `initContainers[]` / `containers[]` | — | Same structure as `deployment`, with one difference: on a cronjob's `initContainers`, `securityContext` and `capabilities` go under `container.securityContext` / `container.capabilities` (rather than at the item's root, as with `deployment.initContainers`). |
| `volumes[]` | — | Same structure as [`volumes`](#volumes). |

#### `postgres` (embedded database on a component)

Creates a dedicated CloudNativePG `Cluster` + a `kubernetes.io/basic-auth` Secret, specific to this component (named `<component-resource>-postgres` / `-postgres-secret`).

| Key | Default | Description |
|---|---|---|
| `enabled` | `false` | |
| `instances` | `1` | |
| `resources` | — | |
| `storage.size` / `storage.storageClassName` | falls back to `addons.postgres.storage.*` | |
| `repository.image` / `repository.tag` | falls back to `addons.postgres.image.*` | |
| `cluster.username` | `app` | |
| `cluster.password` | — | |
| `cluster.database` | `app` | |
| `postInitTemplateSQL[]` / `postInitSQL[]` / `postInitApplicationSQL[]` | — | Run at CloudNativePG bootstrap. |
| `backup.destinationPath`, `backup.endpointURL` | — | `barmanObjectStore` backup (S3). Expects a `<name>-backup-secret` Secret with the `ACCESS_KEY_ID` / `SECRET_ACCESS_KEY` keys. |
| `monitoring` | `false` | `enablePodMonitor`. |

### RBAC

If `global.rbac.enabled: true`, the chart creates a `ServiceAccount`, an associated token-type `Secret`, a `ClusterRole` (`global.rbac.rules`) and a `ClusterRoleBinding`, then automatically mounts that ServiceAccount (`automountServiceAccountToken: true`) on **every** generated pod (deployments, cronjobs, startup jobs). `global.rbac.serviceAccountName` and `global.rbac.clusterRoleName` are then required.

### Addons

Addons are normalized into the same shape as a `component` (internal `commons.withAddons` function): they too produce `Deployment`/`Service`/`Ingress`/etc. through the same templates.

#### `addons.vscode`

[code-server](https://github.com/coder/code-server) instance (VS Code in the browser).

| Key | Default |
|---|---|
| `enabled` | `false` |
| `image.repository` | `lscr.io/linuxserver/code-server` |
| `image.tag` | `4.118.0` |
| `service.port` | `8443` |
| `ingress.enabled` | `false` |
| `volumes[]` | Extra workspaces, each mounted under `/config/workspace/<name>` (dedicated PVC, `useExisting: true` by default). |
| `securityContext.runAsUser` / `runAsGroup` / `fsGroup` | `0` / `1000` / `1000` |

#### `addons.redis`

Redis instance (Deployment + Service + `1Gi` PVC by default). When enabled, a `wait-for-redis` initContainer is automatically added to **every** `components` entry (deployments and cronjobs).

| Key | Default |
|---|---|
| `enabled` | `false` |
| `name` | `redis` |
| `image.repository` | `redis` |
| `image.tag` | `8.8.0-alpine` |
| `port` | `6379` |
| `storage.size` / `storage.storageClassName` | falls back to `global.pvc.storage.*` |
| `password` | `""` |

If `password` is set, a `<release>-redis-auth` Secret is generated, Redis starts with `--requirepass`, and the `wait-for-redis` initContainer (injected everywhere) as well as consumers can retrieve the password via `__addons__redis__password` / `__addons__redis__password_secret` (see [`commons.getValue`](#environment-variables-and-commonsgetvalue)). Left empty (the default), Redis stays unauthenticated, as before.

#### `addons.pgadmin`

[pgAdmin4](https://www.pgadmin.org/) instance, automatically pre-configured (generated `servers.json` and `pgpass` files) with **every** component and the `postgres` addon that have `postgres.enabled: true`.

| Key | Default |
|---|---|
| `enabled` | `false` |
| `image.repository` | `dpage/pgadmin4` |
| `image.tag` | `9.15.0` |
| `auth.email` / `auth.password` | `test@test.com` / `changeme` |
| `service.port` | `80` |
| `ingress` | Unlike the other addons, this block is used **as-is** (no merged defaults): it must therefore contain the full structure of an `ingress` (see [`ingress`](#ingress)) if you want to enable it. |

#### `addons.postgres`

**Shared** CloudNativePG cluster, usable by every component via `__addons__postgres__*` (see [`commons.getValue`](#environment-variables-and-commonsgetvalue)). When enabled, a `wait-for-postgres` initContainer is automatically added to every component (deployments and cronjobs).

| Key | Default |
|---|---|
| `enabled` | `false` |
| `storage.size` | `1Gi` |
| `storage.storageClassName` | `""` |
| `image.repository` | `ghcr.io/cloudnative-pg/postgresql` |
| `image.tag` | `18` |
| `cluster.username` / `cluster.password` | `changeme` / `changeme` |
| `cluster.database` | `app` |

### Resource naming

Resource names are generated by the `commons.fullname` helper, which concatenates (avoiding duplicates): the release name, the component name, and the sub-resource's explicit name if it differs from the component name.

| Context | Generated name |
|---|---|
| Global resource (no component) | `<release>` |
| Resources owned by a component (Deployment, Service, Ingress…) | `<release>-<component>` |
| Named sub-resource of a component (PVC, ConfigMap…) | `<release>-<component>-<sub-resource-name>` |

### Values validation

`charts/commons/values.schema.json` validates the structure of `values.yaml` (types, required fields) on every `helm install`/`upgrade`/`template`/`lint`. In particular, it enforces required fields whenever an addon or RBAC is enabled (e.g. `global.rbac.enabled: true` without `serviceAccountName`/`clusterRoleName`, or `addons.pgadmin.enabled: true` without `auth.email`/`auth.password`, fail validation before templates are even rendered). The free-form content of `components[]` is deliberately left unconstrained beyond `name` (required), so as not to block undocumented usage.

### Tests

Templates are covered by [`helm-unittest`](https://github.com/helm-unittest/helm-unittest) (`charts/commons/tests/`), with a realistic test values fixture at `charts/commons/tests/values/values.yaml`. Running locally:

```bash
helm plugin install https://github.com/helm-unittest/helm-unittest
helm lint charts/commons
helm unittest charts/commons
```

The `helm-tests.yml` GitHub Actions workflow runs these commands on every pull request touching `charts/**`. It also validates the rendered YAML (`helm template`, both with default values and with the test values) against the official Kubernetes schema via [`kubeconform`](https://github.com/yannh/kubeconform), ignoring CloudNativePG's `Cluster` resource (a CRD with no locally available schema). This catches structural errors (unknown field, invalid type) that `helm-unittest` assertions don't necessarily cover.
