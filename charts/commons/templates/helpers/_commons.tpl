{{/*
  Récupère le nom du chart (peut être surchargé par .Values.nameOverride)
*/}}
{{- define "commons.name" -}}
{{- if .component }}
{{- default $.Release.Name .component.appNameOverride -}}
{{- else }}
{{- $.Release.Name -}}
{{- end }}
{{- end }}

{{- define "commons.fullname" -}}
{{- $x := $.Release.Name -}}
{{- $x := $.Release.Name -}}
{{- $y := $x -}}
{{- with .component }}
  {{- with .name }}
    {{- $y = . -}}
  {{- end }}
{{- end }}
{{- $z := default $y .name -}}

{{- if and (eq $x $y) (eq $y $z) -}}
  {{- $x -}}
{{- else if and (eq $x $y) (ne $z $x) -}}
  {{- printf "%s-%s" $x $z -}}
{{- else if and (ne $x $y) (eq $y $z) -}}
  {{- printf "%s-%s" $x $y -}}
{{- else -}}
  {{- printf "%s-%s-%s" $x $y $z -}}
{{- end -}}
{{- end -}}




{{/*
  Crée un identifiant chart "nom-version" pour les labels Helm
*/}}
{{- define "commons.chart" -}}
{{- printf "%s-%s" .Release.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
  Labels standards partagés
*/}}
{{- define "commons.labels" -}}
helm.sh/chart: {{ include "commons.chart" . }}
{{ include "commons.selectorLabels" (dict "Release" $.Release "component" .component) }}
app.kubernetes.io/version: {{ default .Chart.Version .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
  Labels utilisés pour les selectors (matchLabels)
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
  Fonction dinamique pour utiliser des variables dans le fichier de valueKeys
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
  Fonction pour recuépérer le username postgres global
*/}}
{{- define "postgres.username" -}}
{{- if .Values.addons.postgres.enabled -}}
{{- include "commons.getValue" (dict "Values" $.Values "Chart" $.Chart "Release" $.Release "component" $.Values.addons.postgres "value" "__addons__postgres__username") }}
{{- end }}
{{- end }}

{{/*
  Fonction pour recuépérer le database postgres global
*/}}
{{- define "postgres.database" -}}
{{- if .Values.addons.postgres.enabled -}}
{{- include "commons.getValue" (dict "Values" $.Values "Chart" $.Chart "Release" $.Release "component" $.Values.addons.postgres "value" "__addons__postgres__database") }}
{{- end }}
{{- end }}

{{/*
  Fonction pour recuépérer le password postgres global
*/}}
{{- define "postgres.password" -}}
{{- if .Values.addons.postgres.enabled -}}
{{- include "commons.getValue" (dict "Values" $.Values "Chart" $.Chart "Release" $.Release "component" $.Values.addons.postgres "value" "__addons__postgres__password") }}
{{- end -}}
{{- end }}

{{/*
  Fonction pour recuépérer le host postgres global
*/}}
{{- define "postgres.host" -}}
{{- if .Values.addons.postgres.enabled -}}
{{- include "commons.getValue" (dict "Values" $.Values "Chart" $.Chart "Release" $.Release "component" $.Values.addons.postgres "value" "__addons__postgres__host") }}
{{- end -}}
{{- end }}