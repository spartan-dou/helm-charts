{{/*
  Nom applicatif d'un component, utilisé pour le label `app.kubernetes.io/name`.
  Vaut le nom de la release par défaut ; `component.appNameOverride` le surcharge.

  Entrée : dict "Release" $.Release "component" <component|nil>
*/}}
{{- define "commons.name" -}}
{{- if .component }}
{{- default $.Release.Name .component.appNameOverride -}}
{{- else }}
{{- $.Release.Name -}}
{{- end }}
{{- end }}

{{/*
  Nom Kubernetes d'une ressource, construit à partir de trois briques dont les
  doublons sont supprimés :

    <release>                                 ressource globale (ni component ni nom)
    <release>-<component>                     ressource propre à un component
    <release>-<component>-<sous-ressource>    sous-ressource nommée (PVC, ConfigMap…)

  Entrée : dict "Release" $.Release "component" <component|nil> "name" <string|nil>
*/}}
{{- define "commons.fullname" -}}
{{- $releaseName := $.Release.Name -}}
{{- $componentName := $releaseName -}}
{{- with .component }}
  {{- with .name }}
    {{- $componentName = . -}}
  {{- end }}
{{- end }}
{{- $resourceName := default $componentName .name -}}

{{- if and (eq $releaseName $componentName) (eq $componentName $resourceName) -}}
  {{- $releaseName -}}
{{- else if and (eq $releaseName $componentName) (ne $resourceName $releaseName) -}}
  {{- printf "%s-%s" $releaseName $resourceName -}}
{{- else if and (ne $releaseName $componentName) (eq $componentName $resourceName) -}}
  {{- printf "%s-%s" $releaseName $componentName -}}
{{- else -}}
  {{- printf "%s-%s-%s" $releaseName $componentName $resourceName -}}
{{- end -}}
{{- end -}}

{{/*
  Valeur du label `helm.sh/chart`, sous la forme `<release>-<version>`.
  (La convention Helm est `<nom-du-chart>-<version>` : ici c'est bien le nom de
  la release qui est utilisé.)
*/}}
{{- define "commons.chart" -}}
{{- printf "%s-%s" .Release.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
  Labels standards posés sur toutes les ressources : les selectorLabels plus
  les métadonnées de provenance (chart, version, gestionnaire).
*/}}
{{- define "commons.labels" -}}
helm.sh/chart: {{ include "commons.chart" . }}
{{ include "commons.selectorLabels" (dict "Release" $.Release "component" .component) }}
app.kubernetes.io/version: {{ default .Chart.Version .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
  Labels utilisés pour les selectors (`matchLabels`, `service.spec.selector`).
  Seul `app` distingue les components entre eux : les deux autres labels valent
  le nom de la release pour toute la release.
*/}}
{{- define "commons.selectorLabels" -}}
app.kubernetes.io/name: {{ include "commons.name" (dict "Release" $.Release "component" .component) }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- if and .component (kindIs "map" .component) (.component.name) }}
app: {{ .component.name }}
{{- else if .name }}
app: {{ .name }}
{{- else }}
app: {{ .Release.Name }}
{{- end }}
{{- end }}

{{/*
  Section racine `secrets` : table d'alias vers des Secrets Kubernetes déjà
  présents dans le namespace (SealedSecret, ExternalSecret, secret créé à la
  main…). La chart ne transporte jamais la valeur, uniquement la référence.

    secrets:
      pg:
        existingSecret: app-pg-credentials
        key: password

  `commons.secretRefName` renvoie le nom du Secret, `commons.secretRefKey` la
  clé (def. `password`). Les deux échouent explicitement sur un alias inconnu.

  Entrée : dict "Values" $.Values "alias" <string>
*/}}
{{- define "commons.secretRef" -}}
{{- $alias := toString (default "" .alias) }}
{{- $secrets := .Values.secrets | default dict }}
{{- if not (hasKey $secrets $alias) }}
  {{- fail (printf "commons: l'alias `%s` est référencé mais absent de la section `secrets` des values" $alias) }}
{{- end }}
{{- $ref := index $secrets $alias }}
{{- if not (kindIs "map" $ref) }}
  {{- fail (printf "commons: `secrets.%s` doit être un objet `{existingSecret, key}`" $alias) }}
{{- end }}
{{- if not $ref.existingSecret }}
  {{- fail (printf "commons: `secrets.%s.existingSecret` est requis" $alias) }}
{{- end }}
{{- toYaml (dict "name" $ref.existingSecret "key" (default "password" $ref.key)) }}
{{- end }}

{{- define "commons.secretRefName" -}}
{{- (include "commons.secretRef" . | fromYaml).name }}
{{- end }}

{{- define "commons.secretRefKey" -}}
{{- (include "commons.secretRef" . | fromYaml).key }}
{{- end }}

{{/*
  Résolution des placeholders dynamiques utilisables dans les values (`env[].value`,
  `env[].valueFrom.secretKeyRef.name`, noms de volumes…). Une valeur qui ne
  commence pas par `__` est renvoyée telle quelle.

  Grammaire : `__<source>__<type>__<champ>`

    source = `addons`     -> ressource partagée de la section `addons`
             `components` -> ressource du component courant
             `secrets`    -> alias de la section racine `secrets` (le `type`
                             porte alors le nom de l'alias)
             `global`     -> `global.var.<type>`
             <nom>        -> nom d'un autre component (pour pvc/configmap/service/secret)

    type   = `postgres` | `redis` | `pvc` | `configmap` | `service` | `secret`

    champ  = postgres : host | username | password | database |
                        password_secret | password_secret_key
             redis    : host | port | password | password_secret | password_secret_key
             autres   : nom de la sous-ressource visée

  Exemples : `__addons__postgres__host`, `__components__pvc__data`,
             `__nginx__service__http`, `__secrets__pg__name`, `__global__domain`.

  Les champs `password` échouent explicitement quand le mot de passe vit dans un
  Secret externe : il n'existe alors nulle part côté Helm.

  Entrée : dict "Values" $.Values "Chart" $.Chart "Release" $.Release
                "component" <component|nil> "value" <valeur brute>
*/}}
{{- define "commons.getValue" -}}
{{- $component := default "" .component }}
{{- $value := toString (default "" .value) }}
{{- $valueKeys := splitList "__" $value }}

{{- if and (gt (len $valueKeys) 2) (eq (index $valueKeys 0) "") }}

  {{- $source := default "" (index $valueKeys 1) }}
  {{- $type := default "" (index $valueKeys 2) }}
  {{- $field := "" -}}
  {{- if ge (len $valueKeys) 4 }}{{- $field = index $valueKeys 3 }}{{- end }}


  {{- if eq $type "postgres" }}
    {{- if eq $field "host" }}
      {{- if eq $source "addons" }}
        {{- $value = printf "%s-postgres-rw" (include "commons.fullname" (dict "Values" $.Values "Release" $.Release "name" .name)) }}
      {{- else if eq $source "components" }}
        {{- $value = printf "%s-postgres-rw" (include "commons.fullname" (dict "Values" $.Values "Release" $.Release "name" .name "component" $component)) }}
      {{- end }}
    {{- else if eq $field "username" }}
      {{- if eq $source "addons" }}
        {{- $value = .Values.addons.postgres.cluster.username }}
      {{- else if eq $source "components" }}
        {{- $value = $component.postgres.cluster.username }}
      {{- end }}
    {{- else if eq $field "password_secret" }}
      {{- $cluster := ternary .Values.addons.postgres.cluster (default dict $component.postgres).cluster (eq $source "addons") }}
      {{- if (default dict $cluster).secretRef }}
        {{- $value = include "commons.secretRefName" (dict "Values" $.Values "alias" $cluster.secretRef) }}
      {{- else if eq $source "addons" }}
        {{- $value = printf "%s-postgres-secret" (include "commons.fullname" (dict "Values" $.Values "Release" $.Release "name" .name)) }}
      {{- else if eq $source "components" }}
        {{- $value = printf "%s-postgres-secret" (include "commons.fullname" (dict "Values" $.Values "Release" $.Release "name" .name "component" $component)) }}
      {{- end }}
    {{- else if eq $field "password_secret_key" }}
      {{- $value = "password" }}
    {{- else if eq $field "password" }}
      {{- $cluster := ternary .Values.addons.postgres.cluster (default dict $component.postgres).cluster (eq $source "addons") }}
      {{- if (default dict $cluster).secretRef }}
        {{- fail (printf "commons: `__%s__postgres__password` est indisponible quand le cluster utilise `cluster.secretRef` : le mot de passe ne transite pas par les values. Utilisez `__%s__postgres__password_secret` avec un `secretKeyRef`." $source $source) }}
      {{- end }}
      {{- $value = $cluster.password }}
    {{- else if eq $field "database" }}
      {{- if eq $source "addons" }}
        {{- $value = default "app" .Values.addons.postgres.cluster.database }}
      {{- else if eq $source "components" }}
        {{- $value = default "app" $component.postgres.cluster.database }}
      {{- end }}
    {{- end }}
  {{- else if and (eq $source "addons") (eq $type "redis") }}
    {{- if eq $field "host" }}
      {{- $value = include "commons.fullname" (dict "Chart" $.Chart "Values" $.Values "Release" $.Release "component" (dict "name" .Values.addons.redis.name)) }}
    {{- else if eq $field "port" }}
      {{- $value = .Values.addons.redis.port }}
    {{- else if eq $field "password" }}
      {{- if .Values.addons.redis.passwordSecretRef }}
        {{- fail "commons: `__addons__redis__password` est indisponible quand `addons.redis.passwordSecretRef` est utilisé : le mot de passe ne transite pas par les values. Utilisez `__addons__redis__password_secret` avec un `secretKeyRef`." }}
      {{- end }}
      {{- $value = .Values.addons.redis.password }}
    {{- else if eq $field "password_secret" }}
      {{- if .Values.addons.redis.passwordSecretRef }}
        {{- $value = include "commons.secretRefName" (dict "Values" $.Values "alias" .Values.addons.redis.passwordSecretRef) }}
      {{- else }}
        {{- $value = include "commons.fullname" (dict "Chart" $.Chart "Values" $.Values "Release" $.Release "name" "auth" "component" (dict "name" .Values.addons.redis.name)) }}
      {{- end }}
    {{- else if eq $field "password_secret_key" }}
      {{- if .Values.addons.redis.passwordSecretRef }}
        {{- $value = include "commons.secretRefKey" (dict "Values" $.Values "alias" .Values.addons.redis.passwordSecretRef) }}
      {{- else }}
        {{- $value = "password" }}
      {{- end }}
    {{- end }}
  {{- else if or (eq $type "pvc") (eq $type "configmap") (eq $type "service") (eq $type "secret") }}
    {{- $c := dict }}
    {{- if not (eq $source "components") }}
      {{- $c = (dict "name" $source) }}
    {{- else }}
      {{- $c = deepCopy $component }}
    {{- end }}
    {{- $value = include "commons.fullname" (dict "Chart" $.Chart "Values" $.Values "Release" $.Release "name" $field "component" $c) }}
  {{- else if eq $source "secrets" }}
    {{- if eq $field "name" }}
      {{- $value = include "commons.secretRefName" (dict "Values" $.Values "alias" $type) }}
    {{- else if eq $field "key" }}
      {{- $value = include "commons.secretRefKey" (dict "Values" $.Values "alias" $type) }}
    {{- else }}
      {{- fail (printf "commons: `%s` est invalide, attendu `__secrets__%s__name` ou `__secrets__%s__key`" $value $type $type) }}
    {{- end }}
  {{- else if eq $source "global" }}
    {{- $value = (index .Values.global.var $type) }}
  {{- end }}

{{- end }}
{{- $value }}
{{- end }}

{{/*
  Raccourcis vers le cluster CloudNativePG partagé (`addons.postgres`), pour les
  templates qui n'ont pas de component sous la main. Rendent une chaîne vide
  quand l'addon est désactivé.

  Entrée : le contexte racine ($).
*/}}
{{- define "commons.postgres.host" -}}
{{- if .Values.addons.postgres.enabled -}}
{{- include "commons.getValue" (dict "Values" $.Values "Chart" $.Chart "Release" $.Release "component" $.Values.addons.postgres "value" "__addons__postgres__host") }}
{{- end }}
{{- end }}

{{- define "commons.postgres.username" -}}
{{- if .Values.addons.postgres.enabled -}}
{{- include "commons.getValue" (dict "Values" $.Values "Chart" $.Chart "Release" $.Release "component" $.Values.addons.postgres "value" "__addons__postgres__username") }}
{{- end }}
{{- end }}

{{/*
  Image d'un cluster CloudNativePG, rendue en `{repository, tag}`. Source unique
  pour le `Cluster` lui-même et pour l'initContainer `wait-for-postgres` qui
  l'attend : les deux ne peuvent donc plus diverger.

  Deux écritures sont acceptées, par priorité décroissante :

    postgres.image.repository / postgres.image.tag       convention de la chart
    postgres.repository.image / postgres.repository.tag  forme historique
    addons.postgres.image.*                              repli

  Entrée : dict "Values" $.Values "postgres" <bloc postgres d'un component ou d'addons>
*/}}
{{- define "commons.postgres.image" -}}
{{- $postgres := .postgres | default dict -}}
{{- $image := $postgres.image | default dict -}}
{{- $legacy := $postgres.repository | default dict -}}
{{- toYaml (dict
  "repository" (default (default .Values.addons.postgres.image.repository $legacy.image) $image.repository)
  "tag" (default (default .Values.addons.postgres.image.tag $legacy.tag) $image.tag)
) -}}
{{- end }}
