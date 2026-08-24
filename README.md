# helm-charts

🇬🇧 [English version](README.en.md)

Charts Helm maison de `spartan-dou`, packagées et publiées via `chart-releaser` sur GitHub Pages.

## Sommaire

- [Installation](#installation)
- [Chart `commons`](#chart-commons)
  - [Vue d'ensemble](#vue-densemble)
  - [`secrets` (références vers des Secrets existants)](#secrets-références-vers-des-secrets-existants)
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
  - [Validation des values](#validation-des-values)
  - [Tests](#tests)
  - [Changelog](#changelog)

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

### `secrets` (références vers des Secrets existants)

Section racine optionnelle : une table d'**alias** vers des Secrets Kubernetes **déjà présents dans le namespace** (SealedSecret, ExternalSecret, `kubectl create secret`, opérateur Vault…). La chart ne transporte jamais la valeur, uniquement la référence.

```yaml
secrets:
  pg:
    existingSecret: app-pg-credentials   # Secret de type kubernetes.io/basic-auth
  redis:
    existingSecret: app-redis
    key: redis-password                  # def. `password`
  apiKey:
    existingSecret: app-third-party
    key: api-token
```

Conséquence directe : **aucune donnée sensible ne transite par Helm**. `helm get values <release>`, le Secret de release et un `helm template` ne révèlent que des *noms* de Secrets. La rotation d'un mot de passe se fait dans le cluster, sans toucher aux values ni redéployer la chart.

En contrepartie, les Secrets référencés doivent **exister avant l'installation** : sinon les pods restent en `CreateContainerConfigError` et le cluster CloudNativePG ne bootstrappe pas.

#### Consommation

| Endroit | Clé | Exemple |
|---|---|---|
| Variable d'environnement | `env[].secretRef` | `- name: API_KEY` / `secretRef: apiKey` |
| Postgres (component ou addon) | `cluster.secretRef` | remplace `cluster.password` |
| Redis | `addons.redis.passwordSecretRef` | remplace `addons.redis.password` |
| pgAdmin | `addons.pgadmin.auth.passwordSecretRef` | remplace `addons.pgadmin.auth.password` |
| N'importe quelle value | `__secrets__<alias>__name` / `__secrets__<alias>__key` | nom / clé du Secret référencé |

Le raccourci `secretRef` sur une variable d'environnement produit un `valueFrom.secretKeyRef` complet :

```yaml
env:
  - name: API_KEY
    secretRef: apiKey        # -> secretKeyRef { name: app-third-party, key: api-token }
```

Il est disponible dans les `deployment`, `cronjobs` et `job`, sur les conteneurs comme sur les initContainers.

#### Postgres

`cluster.secretRef` remplace `cluster.password` : la chart **ne génère plus** le Secret `<release>-postgres-secret` et pointe `bootstrap.initdb.secret` sur le Secret référencé. Celui-ci doit être de type `kubernetes.io/basic-auth`, avec les clés `username` et `password` (contrainte CloudNativePG — le champ `key` de l'alias est donc ignoré ici).

`cluster.username` reste requis en clair : CloudNativePG en a besoin comme `owner` du cluster, et ce n'est pas une donnée sensible.

Le placeholder `__<source>__postgres__password_secret` résout automatiquement vers le Secret externe. En revanche `__<source>__postgres__password` **échoue explicitement** : le mot de passe n'existe nulle part côté Helm. Utilisez un `secretKeyRef` :

```yaml
env:
  - name: POSTGRES_PASSWORD
    valueFrom:
      secretKeyRef:
        name: __components__postgres__password_secret
        key: password
```

#### pgAdmin

Le fichier `pgpass` n'est plus rendu dans un ConfigMap. Il est reconstitué au démarrage du pod par un initContainer `render-pgpass`, qui reçoit les mots de passe par `secretKeyRef` et écrit le fichier en `0600` dans un volume `emptyDir` partagé avec pgAdmin.

Ce changement s'applique **aussi au mode historique** (mot de passe en clair dans les values) : le pgpass est désormais construit à partir du Secret généré par la chart, et non plus recopié en clair dans un ConfigMap.

#### Limites

- Les Secrets doivent préexister — la chart ne les crée pas et ne peut pas vérifier leur contenu au rendu. Une clé absente du Secret ne se verra qu'au démarrage du pod.
- Un alias inconnu, ou un `existingSecret` manquant, fait **échouer le rendu** avec un message explicite.
- Les noms d'alias ne peuvent pas contenir `__` (séparateur des placeholders) ; le schéma des values le refuse.
- `components[].secrets[]` continue de générer des Secrets à partir des values : cette section reste réservée aux données **non sensibles**. Pour du sensible, référencez un Secret externe.

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
| `global.ingress.className` | `traefik` | `ingressClassName` par défaut pour tout `ingress` (component ou addon, y compris `addons.pgadmin.ingress`) qui ne définit pas explicitement son propre `className`. |
| `global.ingress.authentikOutpost.*` | Voir [`authentikOutpost`](#authentikoutpost) | Valeurs par défaut (`priority`, `entryPoints`, `serviceName`, `serviceNamespace`, `servicePort`) pour tous les `hosts[].authentikOutpost` du chart, surchargeables par hôte. |

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
| `resourceClaims[]` | — | Ressources DRA, au niveau du pod. Passé tel quel. Voir [DRA](#dynamic-resource-allocation-dra). |
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
- `resources` (passé tel quel, y compris `claims` — voir [DRA](#dynamic-resource-allocation-dra))

> Si `service.ports` est défini sur le component, ses ports sont automatiquement ajoutés à la section `ports` du **premier** conteneur de la liste uniquement (en plus de ses éventuels `additionalsPorts`). Les autres conteneurs ne reçoivent que leurs propres `additionalsPorts`, s'ils en définissent.

Une annotation `checksum/<nom-du-volume>` est automatiquement ajoutée au pod pour chaque volume de type `configMap` généré par la chart (pas les `useExisting`) contenant des `data`, afin de déclencher un rollout quand le contenu du ConfigMap change.

#### Dynamic Resource Allocation (DRA)

[DRA](https://kubernetes.io/docs/concepts/scheduling-eviction/dynamic-resource-allocation/) est GA depuis Kubernetes 1.34 (`resource.k8s.io/v1`). Pour les accélérateurs (GPU, TPU…), il remplace le modèle des device plugins : au lieu de compter une ressource entière (`limits: {nvidia.com/gpu: 1}`), le pod référence une `ResourceClaim` que **le scheduler alloue avant de placer le pod**.

Conséquence pratique : une ressource indisponible laisse le pod `Pending` et réessayé, là où un device plugin pas encore enregistré produisait un `UnexpectedAdmissionError` définitif — typiquement au redémarrage d'un nœud.

Deux blocs, à deux niveaux, et les deux sont nécessaires :

```yaml
components:
  - name: inference
    deployment:
      # 1. Au niveau du pod : quelles claims, et qui les produit.
      resourceClaims:
        - name: gpu
          resourceClaimTemplateName: single-gpu   # ou resourceClaimName pour une claim existante
      containers:
        - name: server
          image:
            repository: ollama/ollama
            tag: latest
          resources:
            requests: {cpu: 400m, memory: 4Gi}
            limits: {cpu: 3000m, memory: 32Gi}
            # 2. Au niveau du conteneur : quelles claims du pod il consomme.
            claims:
              - name: gpu
```

Plusieurs conteneurs d'un même pod peuvent référencer la même claim : c'est le mode de partage de DRA, là où le device plugin exigeait une ressource entière par conteneur.

La chart ne fait que recopier les deux blocs. La `ResourceClaimTemplate` (ou la `ResourceClaim`) et la `DeviceClass` qu'elle vise sont à créer à côté, généralement par le driver du fournisseur.

> La forme attendue est celle de Kubernetes 1.31+, avec `resourceClaimName` / `resourceClaimTemplateName` à la racine de l'entrée. Le bloc `source` imbriqué des versions antérieures est déprécié.

#### Variables d'environnement et `commons.getValue`

Toutes les valeurs de `env[].value` et `env[].valueFrom.secretKeyRef.name` passent par le helper `commons.getValue`. Une valeur "normale" (ex: `prod`) est retournée telle quelle. Une valeur au format `__<source>__<type>__<champ>` est résolue dynamiquement :

| Format | Résout vers |
|---|---|
| `__addons__postgres__host` | Host du cluster CloudNativePG **partagé** (`addons.postgres`) : `<release>-postgres-rw` |
| `__addons__postgres__username` / `__password__` / `__database__` | `addons.postgres.cluster.username` / `.password` / `.database` (def. `app`) |
| `__addons__postgres__password_secret` | Nom du Secret `<release>-postgres-secret`, ou du Secret externe si `cluster.secretRef` |
| `__components__postgres__host` / `__username__` / `__password__` / `__database__` / `__password_secret__` | Idem mais sur le cluster CloudNativePG **embarqué dans le component courant** (`component.postgres.*`) |
| `__addons__redis__host` / `__addons__redis__port` | Host / port du service Redis partagé (`addons.redis`) |
| `__addons__redis__password` | `addons.redis.password` en clair — **échoue** si `passwordSecretRef` est utilisé |
| `__addons__redis__password_secret` / `__password_secret_key__` | Nom / clé du Secret contenant le mot de passe Redis (le Secret externe si `passwordSecretRef`) |
| `__<nom-de-component>__pvc__<nom-du-pvc>` | Nom Kubernetes complet du PVC `<nom-du-pvc>` défini sur le component `<nom-de-component>` (ex : `__nginx__pvc__data-2-pvc`) |
| `__components__pvc__<nom-du-pvc>` | Idem, mais sur le component courant |
| `__<nom>__configmap__<nom>` / `__<nom>__service__<nom>` / `__<nom>__secret__<nom>` | Même principe pour un ConfigMap, un Service ou un Secret |
| `__global__<clé>` | `global.var.<clé>` |
| `__secrets__<alias>__name` / `__secrets__<alias>__key` | Nom / clé du Secret existant désigné par l'alias — voir [`secrets`](#secrets-références-vers-des-secrets-existants) |

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
| `className` | `global.ingress.className` | |
| `annotations` | — | |
| `hosts[].host` | — | |
| `hosts[].paths[].path` | `/` | |
| `hosts[].paths[].pathType` | `Prefix` | |
| `hosts[].paths[].name` | Service du component | Nom du Service backend ; par défaut celui généré pour le component courant. |
| `hosts[].paths[].port` | `80` | Port du Service backend : un entier est rendu comme `port.number`, une chaîne comme `port.name` (port nommé). |
| `hosts[].authentikOutpost` | — | Voir [`authentikOutpost`](#authentikoutpost). |
| `tls[]` | — | Passé tel quel (`toYaml`), format standard `spec.tls` d'un Ingress. |

##### `authentikOutpost`

Génère une `IngressRoute` Traefik (`traefik.io/v1alpha1`) dédiée, qui route
`/outpost.goauthentik.io/` sur cet hôte vers l'outpost Authentik du cluster —
nécessaire pour le mode forward auth **single application** (un provider
par hôte, une policy de groupe par hôte). Opt-in par hôte, pas par ingress :
un `ingress` qui sert plusieurs `hosts[]` peut n'activer ceci que sur
certains.

| Clé | Défaut | Description |
|---|---|---|
| `enabled` | `false` | |
| `name` | Premier label DNS de `host` (ex. `app` pour `app.example.com`) | Suffixe du nom de l'objet `IngressRoute` généré ; à préciser si deux hôtes du même component partagent ce label (rare). |
| `priority` | `global.ingress.authentikOutpost.priority` (`15`) | |
| `entryPoints` | `global.ingress.authentikOutpost.entryPoints` (`["websecure"]`) | |
| `serviceName` | `global.ingress.authentikOutpost.serviceName` (`traefik-outpost`) | |
| `serviceNamespace` | `global.ingress.authentikOutpost.serviceNamespace` (`authentik`) | |
| `servicePort` | `global.ingress.authentikOutpost.servicePort` (`9000`) | |

Le `secretName` TLS de l'`IngressRoute` générée est déduit automatiquement
du bloc `tls[]` de l'`ingress` dont fait partie l'hôte (celui dont
`tls[].hosts` contient `host`) — rien à répéter.

```yaml
components:
  - name: app
    ingress:
      enabled: true
      hosts:
        - host: app.example.com
          authentikOutpost:
            enabled: true
      tls:
        - hosts: [app.example.com]
          secretName: app-tls
```

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
| `image.repository` / `image.tag` | repli sur `addons.postgres.image.*` | Image du `Cluster` CloudNativePG **et** de l'initContainer `wait-for-postgres` qui l'attend. L'écriture historique `repository.image` / `repository.tag` reste acceptée, mais `image.*` est prioritaire. |
| `cluster.username` | `app` | |
| `cluster.password` | — | |
| `cluster.database` | `app` | |
| `postInitTemplateSQL[]` / `postInitSQL[]` / `postInitApplicationSQL[]` | — | Exécutés au bootstrap CloudNativePG. |
| `backup.destinationPath`, `backup.endpointURL` | — | Sauvegarde `barmanObjectStore` (S3). Attend un Secret `<name>-backup-secret` avec les clés `ACCESS_KEY_ID` / `SECRET_ACCESS_KEY`. |
| `monitoring` | `false` | Pose `spec.monitoring.enablePodMonitor` sur le `Cluster`. CloudNativePG crée alors le `PodMonitor` qui expose `/metrics` (port 9187) à Prometheus — l'instance manager sert ces métriques dans tous les cas, sans cette option personne ne vient les chercher. Se règle indépendamment sur chaque `postgres` : l'activer sur `addons.postgres` ne l'active pas sur les bases embarquées dans les components. |

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
| `image.tag` | `4.131.0` |
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
| `image.tag` | `8.8.1-alpine` |
| `port` | `6379` |
| `storage.size` / `storage.storageClassName` | repli sur `global.pvc.storage.*` |
| `password` | `""` |

Si `password` est renseigné, un Secret `<release>-redis-auth` est généré, Redis démarre avec `--requirepass`, et l'initContainer `wait-for-redis` (injecté partout) ainsi que les consommateurs peuvent récupérer le mot de passe via `__addons__redis__password` / `__addons__redis__password_secret` (voir [`commons.getValue`](#variables-denvironnement-et-commonsgetvalue)). Laissé vide (défaut), Redis reste sans authentification, comme avant.

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
| `monitoring` | `false` — voir la ligne `monitoring` de [`postgres`](#postgres-base-embarquée-dans-un-component) |

### Nommage des ressources

Les noms de ressources sont générés par le helper `commons.fullname`, qui concatène (en évitant les doublons) : le nom de la release, le nom du component, et le nom explicite de la sous-ressource s'il diffère du nom du component.

| Contexte | Nom généré |
|---|---|
| Ressource globale (pas de component) | `<release>` |
| Ressources propres à un component (Deployment, Service, Ingress…) | `<release>-<component>` |
| Sous-ressource nommée d'un component (PVC, ConfigMap…) | `<release>-<component>-<nom-de-la-sous-ressource>` |

### Validation des values

`charts/commons/values.schema.json` valide la structure de `values.yaml` (types, champs requis) à chaque `helm install`/`upgrade`/`template`/`lint`. En particulier, il impose les champs requis quand un addon ou le RBAC est activé (ex : `global.rbac.enabled: true` sans `serviceAccountName`/`clusterRoleName`, ou `addons.pgadmin.enabled: true` sans `auth.email`/`auth.password`, échouent la validation avant même le rendu des templates). Le contenu libre de `components[]` n'est volontairement pas contraint au-delà de `name` (requis), pour ne pas bloquer les usages non documentés.

### Tests

Les templates sont couverts par [`helm-unittest`](https://github.com/helm-unittest/helm-unittest) (`charts/commons/tests/`), avec un jeu de values de test réaliste dans `charts/commons/tests/values/values.yaml`. Exécution locale :

```bash
helm plugin install https://github.com/helm-unittest/helm-unittest
helm lint charts/commons
helm unittest charts/commons
```

Le workflow GitHub Actions `helm-tests.yml` exécute ces commandes sur chaque pull request touchant `charts/**`. Il valide aussi le YAML rendu (`helm template`, valeurs par défaut et valeurs de test) contre le schéma Kubernetes officiel via [`kubeconform`](https://github.com/yannh/kubeconform), en ignorant la ressource `Cluster` de CloudNativePG (CRD sans schéma local disponible). Cela attrape des erreurs de structure (champ inconnu, type invalide) que les assertions `helm-unittest` ne couvrent pas forcément.

### Changelog

Les changements visibles depuis les values ou depuis le YAML rendu sont suivis
dans [`charts/commons/CHANGELOG.md`](charts/commons/CHANGELOG.md), avec la liste
des points à vérifier avant de monter d'une version majeure à l'autre.
