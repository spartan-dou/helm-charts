{{/*
  Récupère le nom du chart (peut être surchargé par .Values.nameOverride)
*/}}
{{- define "commons.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "commons.fullname" -}}
{{- $component := default "" .component }}
{{- if .Values.fullnameOverride }}
  {{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
  {{- $baseName := default .Chart.Name .Values.nameOverride }}
  {{- if eq $baseName "commons" }}
    {{- $baseName = "" }}
  {{- end }}
  {{- $full := "" }}
  {{- if and $baseName (not (contains $baseName .Release.Name)) }}
    {{- $full = printf "%s-%s" .Release.Name $baseName }}
  {{- else }}
    {{- $full = .Release.Name }}
  {{- end }}
  {{- $suffix := "" }}
  {{- if and $component (kindIs "map" $component) ($component.name) }}
    {{- $suffix = printf "%s-%s" $suffix $component.name}}
  {{- end }}
  {{- if .name }}
    {{- $suffix = printf "%s-%s" $suffix .name}}
  {{- end }}

  
  {{- if $suffix }}
    {{- $full = printf "%s%s" $full $suffix }}
  {{- end }}
  {{- $full | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}



{{/*
  Crée un identifiant chart "nom-version" pour les labels Helm
*/}}
{{- define "commons.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
  Labels standards partagés
*/}}
{{- define "commons.labels" -}}
helm.sh/chart: {{ include "commons.chart" . }}
{{ include "commons.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
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
{{- $value := default "" .value }}
{{- $valueKeys := splitList "__" $value }}

{{- if and (gt (len $valueKeys) 2) (eq (index $valueKeys 0) "") }}

  {{- $source := default "" (index $valueKeys 1) }}
  {{- $type := default "" (index $valueKeys 2) }}
  {{- $field := default "" (index $valueKeys 3) }}

  {{- if eq $type "postgres" }}
    {{- if eq $field "host" }}
      {{- if eq $source "addons" }}
        {{- $value = printf "%s-rw" (include "commons.fullname" (dict "Chart" $.Chart "Values" $.Values "Release" $.Release "name" .name)) }}
      {{- else if eq $source "components" }}
        {{- $value = printf "%s-rw" (include "commons.fullname" (dict "Chart" $.Chart "Values" $.Values "Release" $.Release "name" .name "component" $component)) }}
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
      {{- $value = include "commons.fullname" (dict "Chart" $.Chart "Values" $.Values "Release" $.Release "name" .Values.addons.redis.name "component" $component) }}
    {{- else if eq $field "port" }}
      {{- $value = .Values.addons.redis.port }}
    {{- end }}
  {{- else if and (eq $type "pvc") }}
  {{- $test := (dict "name" $source) }}
    {{- if not (eq $source "components") }}
    {{- end }}
    {{- $value = include "commons.fullname" (dict "Chart" $.Chart "Values" $.Values "Release" $.Release "name" $field "component" $test) }}
  {{- else if (eq $type "configmap") }}
    {{- if not (eq $source "components") }}
      {{- $component = merge $component (dict "name" $source) }}
    {{- end }}
    {{- $value = include "commons.fullname" (dict "Chart" $.Chart "Values" $.Values "Release" $.Release "name" $field "component" $component) }}
  {{- else if and (eq $type "service") (eq $source "components") }}
    {{- $value = include "commons.fullname" (dict "Chart" $.Chart "Values" $.Values "Release" $.Release "name" $field "component" $component) }}
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