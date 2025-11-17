{{/*
  Récupère le nom du chart (peut être surchargé par .Values.nameOverride)
*/}}
{{- define "commons.name" -}}
{{- .Release.Name }}
{{- end }}

{{- define "commons.fullname" -}}
{{- $x := .Release.Name -}}
{{- $y := default .Release.Name .component.name -}}
{{- $z := .name -}}

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
{{ include "commons.selectorLabels" . }}
app.kubernetes.io/version: {{ default .Chart.Version .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
  Labels utilisés pour les selectors (matchLabels)
*/}}
{{- define "commons.selectorLabels" -}}
app.kubernetes.io/name: {{ include "commons.name" . }}
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
        {{- $value = printf "%s-postgres-rw" (include "commons.fullname" (dict "Chart" $.Chart "Values" $.Values "Release" $.Release "name" .name)) }}
      {{- else if eq $source "components" }}
        {{- $value = printf "%s-postgres-rw" (include "commons.fullname" (dict "Chart" $.Chart "Values" $.Values "Release" $.Release "name" .name "component" $component)) }}
      {{- end }}
    {{- else if eq $field "username" }}
      {{- if eq $source "addons" }}
        {{- $value = .Values.addons.postgres.cluster.username }}
      {{- else if eq $source "components" }}
        {{- $value = $component.postgres.cluster.username }}
      {{- end }}
    {{- else if eq $field "password_secret" }}
      {{- if eq $source "addons" }}
        {{- $value = printf "%s-postgres-secret" (include "commons.fullname" (dict "Chart" $.Chart "Values" $.Values "Release" $.Release "name" .name)) }}
      {{- else if eq $source "components" }}
        {{- $value = printf "%s-postgres-secret" (include "commons.fullname" (dict "Chart" $.Chart "Values" $.Values "Release" $.Release "name" .name "component" $component)) }}
      {{- end }}
    {{- else if eq $field "password" }}
      {{- if eq $source "addons" }}
        {{- $value = .Values.addons.postgres.cluster.password }}
      {{- else if eq $source "components" }}
        {{- $value = $component.postgres.cluster.password }}
      {{- end }}
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
    {{- end }}
  {{- else if or (eq $type "pvc") (eq $type "configmap") (eq $type "service") }}
    {{- $c := dict }}
    {{- if not (eq $source "components") }}
      {{- $c = (dict "name" $source) }}
    {{- else }}
      {{- $c = deepCopy $component }}
    {{- end }}
    {{- $value = include "commons.fullname" (dict "Chart" $.Chart "Values" $.Values "Release" $.Release "name" $field "component" $c) }}
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
{{- include "commons.getValue" (dict "Values" $.Values "Chart" $.Chart "Release" $.Release "component" $.Values.addons.postgres "value" "__addons__postgres__databasse") }}
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

  Fonction pour recuépérer le host postgres global
*/}}
{{- define "postgres.host" -}}
{{- if .Values.addons.postgres.enabled -}}
{{- include "commons.getValue" (dict "Values" $.Values "Chart" $.Chart "Release" $.Release "component" $.Values.addons.postgres "value" "__addons__postgres__host") }}
{{- end -}}
{{- end }}