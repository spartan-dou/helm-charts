# Changelog — chart `commons`

Ce fichier ne retrace que les changements visibles depuis les values ou depuis
le YAML rendu. Les montées de tag d'images faites par Renovate ne sont pas
listées.

## 0.8.0

Première version stable depuis la **0.7.16**. Les préversions `0.8.0-beta.1` et
`0.8.0-beta.2` sont incluses ici.

### À vérifier avant de monter depuis 0.7.16

Ces points changent un comportement existant. Le reste de la 0.8.0 est additif.

1. **Les values sont désormais validées** (`values.schema.json`). Une
   configuration qui passait en 0.7.16 peut être refusée avant même le rendu :
   - `global.rbac.enabled: true` sans `serviceAccountName` **et**
     `clusterRoleName` ;
   - `addons.pgadmin.enabled: true` sans `auth.email`, ni `auth.password` ou
     `auth.passwordSecretRef` ;
   - `addons.postgres.enabled: true` sans `cluster.username`, ni
     `cluster.password` ou `cluster.secretRef`.

   `components[]` reste volontairement libre au-delà de `name`.

2. **`global.ingress.className` est maintenant réellement appliqué.** Il était
   déclaré dans les values mais lu par aucun template. Tout `ingress` qui ne
   définit pas son propre `className` reçoit désormais la valeur globale
   (`traefik` par défaut) au lieu de n'avoir aucun `ingressClassName`. Pour
   qu'un ingress n'en porte aucun, il faut mettre `global.ingress.className: ""`.

3. **Le `pgpass` de pgAdmin n'est plus rendu dans un ConfigMap.** Il est
   reconstitué au démarrage par un initContainer `render-pgpass`, en `0600`
   dans un `emptyDir`, à partir des Secrets Postgres. Cela vaut aussi pour le
   mode historique (mot de passe en clair dans les values). Le ConfigMap
   pgAdmin ne contient plus que `servers.json`.

4. **`fsGroup` des addons `vscode` et `pgadmin` a changé de niveau** : il était
   posé sur le `securityContext` du conteneur, où le champ n'existe pas. Il est
   maintenant sur celui du pod, fusionné avec `global.securityContext`.

5. **Port du backend d'un Ingress** : un entier est rendu en `port.number` (et
   non plus toujours en `port.name`), une chaîne reste en `port.name`.

6. **Redis démarre via `args` et non `command`.** L'entrypoint de l'image
   reprend la main : quand l'authentification est activée, le process ne tourne
   plus en root faute de `securityContext.runAsUser`.

7. **`service.ports` n'est injecté que sur le premier conteneur** d'un
   deployment. Les conteneurs suivants ne portent que leurs propres
   `additionalsPorts`. Sans effet sur les components mono-conteneur.

8. **`nodePort` est enfin rendu** pour un service `type: NodePort` — la
   condition testait le mauvais contexte et l'ignorait silencieusement.

9. **`postgres.image.{repository,tag}` est désormais pris en compte** sur un
   `postgres` de component ou d'addon. Jusqu'ici seule la forme
   `postgres.repository.{image,tag}` était lue, et une values écrivant
   `postgres.image.tag` en croyant surcharger l'image du cluster était
   **ignorée en silence**. Vérifie tes values : une clé jusque-là sans effet
   peut maintenant en avoir un. Les deux écritures restent acceptées,
   `image.*` étant prioritaire.

10. **`TZ` est maintenant injecté dans les initContainers de CronJob.** Il
    l'était déjà dans tous les autres conteneurs et initContainers, et le
    README le documentait comme tel.

11. **Labels standards ajoutés** sur les `CronJob`, `Job`, Secrets de component
    et Secrets CloudNativePG, qui n'en portaient aucun.

12. **Helpers renommés sous le préfixe `commons.`** — sans effet sauf si une
    chart parente appelait directement `include "containers.envs"`,
    `"containers.probes"`, `"pod.securityContext"`, `"pgadmin.*"` ou
    `"postgres.*"`.

### Ajouts

- **Section racine `secrets`** : table d'alias vers des Secrets Kubernetes déjà
  présents dans le namespace. Aucune donnée sensible ne transite plus par Helm.
  Consommable via `env[].secretRef`, `postgres.cluster.secretRef`,
  `addons.redis.passwordSecretRef`, `addons.pgadmin.auth.passwordSecretRef` et
  les placeholders `__secrets__<alias>__name` / `__key`.
  `__<source>__postgres__password` échoue désormais explicitement quand le
  cluster utilise `cluster.secretRef`, au lieu de rendre une valeur vide.
- **`hosts[].authentikOutpost`** : génère une `IngressRoute` Traefik routant
  `/outpost.goauthentik.io/` vers l'outpost Authentik, pour le mode forward
  auth *single application*. Opt-in par hôte ; `secretName` TLS déduit du bloc
  `tls[]` correspondant.
- **`deployment.resourceClaims[]`** : support DRA au niveau du pod, en
  complément de `containers[].resources.claims` qui passait déjà.
- **`addons.redis.password`** : la clé existait mais n'était consommée par
  aucun template — Redis tournait sans authentification. Elle génère maintenant
  un Secret `<release>-redis-auth`, démarre Redis avec `--requirepass` et
  alimente l'initContainer `wait-for-redis`.
- **Métadonnées de chart** (`keywords`, `home`, `sources`, `maintainers`) et
  `.helmignore`.

### Corrections

- `templates/secret.yaml` n'émettait pas de `---` entre deux Secrets : deux
  Secrets ou plus produisaient un document YAML invalide.
- `helm template` plantait (`nil pointer`) sur un component déclarant un
  `ingress` sans bloc `service`.
- Le helper `postgres.database` était cassé par une faute de frappe.
- Précédence du `default "latest"` sur le tag de l'image Redis (appliqué au
  dict entier au lieu du champ `tag`).

### Interne

- Templates `commons.waitForRedisInitContainer` /
  `commons.waitForSharedPostgresInitContainer` extraits de leurs 4 points
  d'appel dupliqués.
- Bloc `env` et sondes factorisés dans `commons.containers.env` /
  `commons.containers.probes` ; image du cluster Postgres résolue par
  `commons.postgres.image`, partagée entre le `Cluster` et son initContainer
  d'attente.
- Couverture `helm-unittest` étendue, et validation `kubeconform` du YAML rendu
  ajoutée à la CI.

---

Pour l'historique antérieur, voir les
[releases GitHub](https://github.com/spartan-dou/helm-charts/releases).
