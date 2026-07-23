# helm-charts

Charts Helm maison de `spartan-dou`, packagées et publiées via `chart-releaser` sur GitHub Pages.

## Sommaire

- [Installation](#installation)
- [Chart `commons`](#chart-commons)
  - [Vue d'ensemble](#vue-densemble)
  - [`global`](#global)
  - [Un `component`](#un-component)
    - [`deployment`](#deployment)
    - [Variables d'environnement et `commons.getValue`](#variables-denvironnement-et-commonsgetvalue)
    - [Probes](#probes)
    - [`volumes`](#volumes)
    - [`service`](#service)
    - [`ingress`](#ingress)
    - [`secrets`](#secrets)
    - [`cronjobs`](#cronjobs)
    - [`postgres` (base embarquée dans un component)](#postgres-base-embarquée-dans-un-component)
  - [RBAC](#rbac)
  - [Addons](#addons)
    - [`addons.vscode`](#addonsvscode)
    - [`addons.redis`](#addonsredis)
    - [`addons.pgadmin`](#addonspgadmin)
    - [`addons.postgres`](#addonspostgres)
  - [Nommage des ressources](#nommage-des-ressources)
  - [Tests](#tests)
  - [Points d'attention connus](#points-dattention-connus)

## Installation

[Helm](https://helm.sh) doit être installé. [CloudNativePG](https://github.com/cloudnative-pg/cloudnative-pg), [Traefik](https://github.com/traefik/traefik) et [cert-manager](https://github.com/cert-manager/cert-manager) doivent être installés dans le cluster cible (CloudNativePG uniquement si vous utilisez les fonctionnalités `postgres`).

```bash
helm repo add dou-charts https://spartan-dou.github.io/helm-charts
helm repo update
helm search repo dou-charts
```

Installer une chart :

```bash
helm install my-<chart-name> dou-charts/<chart-name>
```

Désinstaller :

```bash
helm delete my-<chart-name>
```

![Helm Unit Tests](https://github.com/spartan-dou/helm-charts/actions/workflows/helm-tests.yml/badge.svg)

## Chart `commons`

### Vue d'ensemble

`commons` est une chart générique "à la carte" : au lieu de définir un `Deployment`/`Service`/`Ingress` par application, on décrit chaque application comme un objet dans la liste `components`, et la chart génère toutes les ressources Kubernetes correspondantes. Elle fournit en plus des **addons** prêts à l'emploi (VS Code, Redis, pgAdmin, PostgreSQL via CloudNativePG) que n'importe quel `component` peut consommer.

Une seule release peut ainsi porter plusieurs applications indépendantes (plusieurs `Deployment`, `Service`, `Ingress`, etc.), toutes préfixées par le nom de la release.

Exemple minimal :

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

Voir `charts/commons/tests/values/values.yaml` pour un exemple complet couvrant la quasi-totalité des fonctionnalités décrites ci-dessous (il sert aussi de fixture aux tests `helm-unittest`).

### `global`

| Clé | Défaut | Description |
|---|---|---|
| `global.timezone` | `Europe/Paris` | Injecté en variable d'env `TZ` dans **tous** les conteneurs/initContainers (deployment, cronjob, job), et utilisé comme `postgresql.parameters.timezone` sur les clusters CloudNativePG. |
| `global.securityContext` | `{}` | `securityContext` de pod par défaut, fusionné (`mergeOverwrite`) avec le `securityContext` propre à chaque `deployment`/`cronjob` (les clés définies au niveau du component prennent le dessus). Accepte n'importe quel champ Kubernetes valide (`runAsUser`, `runAsGroup`, `fsGroup`, `supplementalGroups`, …). |
| `global.pvc.storage.size` | `1Gi` | Taille par défaut des PVC quand `storage.size` n'est pas précisé sur le volume. |
| `global.pvc.storage.storageClassName` | `""` | StorageClass par défaut des PVC. |
| `global.pvc.storage.accessMode` | `ReadWriteOnce` | AccessMode par défaut des PVC. |
| `global.rbac.enabled` | `false` | Voir [RBAC](#rbac). |
| `global.rbac.serviceAccountName` | — | Requis si `rbac.enabled: true`. |
| `global.rbac.clusterRoleName` | — | Requis si `rbac.enabled: true`. |
| `global.rbac.rules` | — | Liste de `PolicyRule` (format RBAC Kubernetes standard) pour le `ClusterRole`. |
| `global.var` | `{}` | Espace de clé/valeur libre, accessible depuis n'importe quelle `env[].value` via `__global__<clé>` (voir [`commons.getValue`](#variables-denvironnement-et-commonsgetvalue)). |
| `global.ingress.className` | `traefik` | ⚠️ Défini dans les valeurs par défaut mais **non consommé** par les templates actuels : chaque `ingress` (component ou addon) doit fixer son propre `className`. |

### Un `component`

Chaque entrée de `components` (liste) accepte :

| Clé | Description |
|---|---|
| `name` | Nom logique du component. Sert à construire les noms de ressources ([voir plus bas](#nommage-des-ressources)) et le nom par défaut du premier conteneur. |
| `appNameOverride` | Surcharge le label `app.kubernetes.io/name` indépendamment de `name`. |
| `deployment` | Voir [`deployment`](#deployment). |
| `service` | Voir [`service`](#service). |
| `ingress` | Voir [`ingress`](#ingress). |
| `secrets` | Voir [`secrets`](#secrets). |
| `cronjobs` | Voir [`cronjobs`](#cronjobs). |
| `postgres` | Voir [`postgres`](#postgres-base-embarquée-dans-un-component). |

#### `deployment`

| Clé | Défaut | Description |
|---|---|---|
| `replicas` | `1` | |
| `strategy.type` | `RollingUpdate` | |
| `securityContext` | — | Fusionné avec `global.securityContext`. |
| `nodeSelector` | — | |
| `hostNetwork` | — | |
| `initContainers[]` | — | `name` (def. nom du component), `image.repository`, `image.tag` (def. `latest`), `securityContext`, `command`, `args`, `env[]`, `volumeMounts[]`. |
| `containers[]` | — | Voir ci-dessous. |
| `volumes[]` | — | Voir [`volumes`](#volumes). |

Chaque entrée de `containers[]` :

- `name` (def. nom du component)
- `image.repository`, `image.tag` (def. `latest`)
- `command`, `args`
- `securityContext`
- `env[]` (voir [ci-dessous](#variables-denvironnement-et-commonsgetvalue))
- `lifecycle` (passé tel quel)
- `volumeMounts[]` (`name`, `mountPath`, `subPath` optionnel)
- `additionalsPorts[]` (`name`, `containerPort`, `protocol` def. `TCP`, `hostPort` optionnel) — *(nom de champ tel quel dans la chart, avec le "s")*
- `livenessProbe` / `readinessProbe` / `startupProbe` / `probe` — voir [Probes](#probes)
- `resources`

> Si `service.ports` est défini sur le component, ses ports sont automatiquement ajoutés à la section `ports` de **chaque** conteneur de la liste (en plus de `additionalsPorts`) — utile pour un conteneur unique, à garder en tête si plusieurs conteneurs cohabitent dans le même pod.

Une annotation `checksum/<nom-du-volume>` est automatiquement ajoutée au pod pour chaque volume de type `configMap` généré par la chart (pas les `useExisting`) contenant des `data`, afin de déclencher un rollout quand le contenu du ConfigMap change.

#### Variables d'environnement et `commons.getValue`

Toutes les valeurs de `env[].value` et `env[].valueFrom.secretKeyRef.name` passent par le helper `commons.getValue`. Une valeur "normale" (ex: `prod`) est retournée telle quelle. Une valeur au format `__<source>__<type>__<champ>` est résolue dynamiquement :

| Format | Résout vers |
|---|---|
| `__addons__postgres__host` | Host du cluster CloudNativePG **partagé** (`addons.postgres`) : `<release>-postgres-rw` |
| `__addons__postgres__username` / `__password__` / `__database__` | `addons.postgres.cluster.username` / `.password` / `.database` (def. `app`) |
| `__addons__postgres__password_secret` | Nom du Secret `<release>-postgres-secret` |
| `__components__postgres__host` / `__username__` / `__password__` / `__database__` / `__password_secret__` | Idem mais sur le cluster CloudNativePG **embarqué dans le component courant** (`component.postgres.*`) |
| `__addons__redis__host` / `__addons__redis__port` | Host / port du service Redis partagé (`addons.redis`) |
| `__<nom-de-component>__pvc__<nom-du-pvc>` | Nom Kubernetes complet du PVC `<nom-du-pvc>` défini sur le component `<nom-de-component>` (ex : `__nginx__pvc__data-2-pvc`) |
| `__components__pvc__<nom-du-pvc>` | Idem, mais sur le component courant |
| `__<nom>__configmap__<nom>` / `__<nom>__service__<nom>` | Même principe pour un ConfigMap ou un Service |
| `__global__<clé>` | `global.var.<clé>` |

Exemple (tiré des tests) :

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

`probe` définit une configuration commune utilisée comme valeur par défaut pour `livenessProbe`, `readinessProbe` et `startupProbe` si ces derniers ne sont pas définis individuellement. Chacune accepte `tcpSocket`, `exec` ou `httpGet` (`path` def. `/`, `port` def. `http`), plus :

| Probe | `initialDelaySeconds` | `periodSeconds` | `timeoutSeconds` | `failureThreshold` |
|---|---|---|---|---|
| `livenessProbe` | 10 | 10 | 2 | 3 |
| `readinessProbe` | 5 | 5 | 2 | 3 |
| `startupProbe` | 0 | 5 | 2 | 30 |

#### `volumes`

Chaque entrée de `deployment.volumes[]` (et `cronjobs[].initContainers[]/containers[]` volumes) est l'un des trois cas suivants :

- **ConfigMap généré par la chart** :
  ```yaml
  - name: config
    configMap:
      data:
        config.yaml: "key: value"
  ```
  Génère un objet `ConfigMap` (voir `templates/configmap.yaml`). Ajoutez `defaultMode` / `readOnly` au besoin.

- **ConfigMap déjà existant dans le cluster** :
  ```yaml
  - name: config
    configMap:
      useExisting: true
      name: mon-configmap-existant
  ```

- **PVC généré par la chart** :
  ```yaml
  - name: data
    pvc:
      name: data-pvc
      storage:
        size: 5Gi
        storageClassName: local-path
        accessMode: ReadWriteOnce
  ```
  Génère un objet `PersistentVolumeClaim` (voir `templates/pvc.yaml`), avec repli sur `global.pvc.storage.*` pour les champs non précisés. `storage.volumeMode` et `storage.selector` sont également supportés.

- **PVC déjà existant** : `pvc.useExisting: true` + `pvc.name`.

- **Volume brut Kubernetes** : toute autre clé sous `configMap`/`pvc` absente — l'entrée est passée telle quelle (`toYaml`) dans `volumes:`, ce qui permet d'utiliser n'importe quel type de volume Kubernetes non couvert ci-dessus (`emptyDir`, `secret`, `hostPath`, …).

#### `service`

| Clé | Défaut | Description |
|---|---|---|
| `type` | `ClusterIP` | |
| `annotations` | — | |
| `ports[].name` | — | |
| `ports[].port` | — | |
| `ports[].targetPort` | = `port` | |
| `ports[].protocol` | — | |
| `ports[].nodePort` | — | Uniquement pris en compte si `type: NodePort`. |

#### `ingress`

| Clé | Défaut | Description |
|---|---|---|
| `enabled` | `false` | |
| `className` | — | |
| `annotations` | — | |
| `hosts[].host` | — | |
| `hosts[].paths[].path` | `/` | |
| `hosts[].paths[].pathType` | `Prefix` | |
| `hosts[].paths[].name` | Service du component | Nom du Service backend ; par défaut celui généré pour le component courant. |
| `hosts[].paths[].port` | `80` | Nom du port du Service backend. |
| `tls[]` | — | Passé tel quel (`toYaml`), format standard `spec.tls` d'un Ingress. |

#### `secrets`

Liste de Secrets `Opaque` (ou autre `type`) attachés au component :

```yaml
secrets:
  - name: mon-secret
    data:
      cle: valeur   # encodé en base64 automatiquement
    type: Opaque    # défaut
```

#### `cronjobs`

Chaque entrée génère un `CronJob`. Si `runOnStartup: true` **et** `enabled: true`, un `Job` (`ttlSecondsAfterFinished: 60`) est **en plus** créé avec la même spec, pour exécuter la tâche immédiatement au déploiement.

| Clé | Défaut | Description |
|---|---|---|
| `enabled` | — | Doit être `true` pour que le CronJob soit rendu. |
| `schedule` | — | Requis. |
| `runOnStartup` | `false` | Voir ci-dessus. |
| `concurrencyPolicy` | — | |
| `startingDeadlineSeconds` | — | |
| `successfulJobsHistoryLimit` | `5` | |
| `failedJobsHistoryLimit` | `5` | |
| `suspend` | — | |
| `restartPolicy` | `Never` | |
| `securityContext`, `nodeSelector` | — | |
| `initContainers[]` / `containers[]` | — | Même structure que pour `deployment`, à une différence près : sur les `initContainers` d'un cronjob, `securityContext` et `capabilities` se placent sous `container.securityContext` / `container.capabilities` (et non à la racine de l'item comme pour `deployment.initContainers`). |
| `volumes[]` | — | Même structure que [`volumes`](#volumes). |

#### `postgres` (base embarquée dans un component)

Crée un `Cluster` CloudNativePG dédié + un Secret `kubernetes.io/basic-auth`, propres à ce component (nom `<ressource-du-component>-postgres` / `-postgres-secret`).

| Clé | Défaut | Description |
|---|---|---|
| `enabled` | `false` | |
| `instances` | `1` | |
| `resources` | — | |
| `storage.size` / `storage.storageClassName` | repli sur `addons.postgres.storage.*` | |
| `repository.image` / `repository.tag` | repli sur `addons.postgres.image.*` | |
| `cluster.username` | `app` | |
| `cluster.password` | — | |
| `cluster.database` | `app` | |
| `postInitTemplateSQL[]` / `postInitSQL[]` / `postInitApplicationSQL[]` | — | Exécutés au bootstrap CloudNativePG. |
| `backup.destinationPath`, `backup.endpointURL` | — | Sauvegarde `barmanObjectStore` (S3). Attend un Secret `<name>-backup-secret` avec les clés `ACCESS_KEY_ID` / `SECRET_ACCESS_KEY`. |
| `monitoring` | `false` | `enablePodMonitor`. |

### RBAC

Si `global.rbac.enabled: true`, la chart crée un `ServiceAccount`, un `Secret` de type token associé, un `ClusterRole` (`global.rbac.rules`) et un `ClusterRoleBinding`, puis monte automatiquement ce ServiceAccount (`automountServiceAccountToken: true`) sur **tous** les pods générés (deployments, cronjobs, jobs de démarrage). `global.rbac.serviceAccountName` et `global.rbac.clusterRoleName` sont alors obligatoires.

### Addons

Les addons sont normalisés dans le même format qu'un `component` (fonction interne `commons.withAddons`) : ils produisent donc, eux aussi, `Deployment`/`Service`/`Ingress`/etc. à travers les mêmes templates.

#### `addons.vscode`

Instance [code-server](https://github.com/coder/code-server) (VS Code dans le navigateur).

| Clé | Défaut |
|---|---|
| `enabled` | `false` |
| `image.repository` | `lscr.io/linuxserver/code-server` |
| `image.tag` | `4.118.0` |
| `service.port` | `8443` |
| `ingress.enabled` | `false` |
| `volumes[]` | Espaces de travail supplémentaires, chacun monté sous `/config/workspace/<name>` (PVC dédié, `useExisting: true` par défaut). |
| `securityContext.runAsUser` / `runAsGroup` / `fsGroup` | `0` / `1000` / `1000` |

#### `addons.redis`

Instance Redis (Deployment + Service + PVC `1Gi` par défaut). Quand elle est activée, un initContainer `wait-for-redis` est automatiquement ajouté à **tous** les `components` (deployments et cronjobs).

| Clé | Défaut |
|---|---|
| `enabled` | `false` |
| `name` | `redis` |
| `image.repository` | `redis` |
| `image.tag` | `8.8.0-alpine` |
| `port` | `6379` |
| `storage.size` / `storage.storageClassName` | repli sur `global.pvc.storage.*` |

> Aucune authentification n'est configurée par la chart actuellement (pas de `requirepass`) : Redis est déployé sans mot de passe même si un champ `password` est renseigné dans les values, il n'est pas encore consommé par les templates.

#### `addons.pgadmin`

Instance [pgAdmin4](https://www.pgadmin.org/), pré-configurée automatiquement (fichiers `servers.json` et `pgpass` générés) avec **tous** les components et l'addon `postgres` qui ont `postgres.enabled: true`.

| Clé | Défaut |
|---|---|
| `enabled` | `false` |
| `image.repository` | `dpage/pgadmin4` |
| `image.tag` | `9.15.0` |
| `auth.email` / `auth.password` | `test@test.com` / `changeme` |
| `service.port` | `80` |
| `ingress` | Contrairement aux autres addons, ce bloc est utilisé **tel quel** (pas de valeurs par défaut fusionnées) : il doit donc contenir la structure complète d'un `ingress` (voir [`ingress`](#ingress)) si vous voulez l'activer. |

#### `addons.postgres`

Cluster CloudNativePG **partagé**, consommable par tous les components via `__addons__postgres__*` (voir [`commons.getValue`](#variables-denvironnement-et-commonsgetvalue)). Quand il est activé, un initContainer `wait-for-postgres` est automatiquement ajouté à tous les components (deployments et cronjobs).

| Clé | Défaut |
|---|---|
| `enabled` | `false` |
| `storage.size` | `1Gi` |
| `storage.storageClassName` | `""` |
| `image.repository` | `ghcr.io/cloudnative-pg/postgresql` |
| `image.tag` | `18` |
| `cluster.username` / `cluster.password` | `changeme` / `changeme` |
| `cluster.database` | `app` |

### Nommage des ressources

Les noms de ressources sont générés par le helper `commons.fullname`, qui concatène (en évitant les doublons) : le nom de la release, le nom du component, et le nom explicite de la sous-ressource s'il diffère du nom du component.

| Contexte | Nom généré |
|---|---|
| Ressource globale (pas de component) | `<release>` |
| Ressources propres à un component (Deployment, Service, Ingress…) | `<release>-<component>` |
| Sous-ressource nommée d'un component (PVC, ConfigMap…) | `<release>-<component>-<nom-de-la-sous-ressource>` |

### Tests

Les templates sont couverts par [`helm-unittest`](https://github.com/helm-unittest/helm-unittest) (`charts/commons/tests/`), avec un jeu de values de test réaliste dans `charts/commons/tests/values/values.yaml`. Exécution locale :

```bash
helm plugin install https://github.com/helm-unittest/helm-unittest
helm lint charts/commons
helm unittest charts/commons
```

Le workflow GitHub Actions `helm-tests.yml` exécute les deux commandes ci-dessus sur chaque pull request touchant `charts/**`.

### Points d'attention connus

- `global.ingress.className` n'est actuellement lu par aucun template : chaque `ingress` (component ou addon) doit définir son propre `className`.
- `addons.redis.password` n'est pas câblé côté template (pas d'authentification Redis).
- Si `service.ports` est renseigné, ses ports sont dupliqués sur **tous** les conteneurs d'un `deployment` multi-conteneurs (pas seulement le conteneur principal).
