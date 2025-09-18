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
  Détermine le nom du service account à utiliser
*/}}
{{- define "commons.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "commons.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
  Fonction dinamique pour utiliser des variables dans le fichier de values
*/}}
{{- define "commons.getValue" -}}
{{- $component := default "" .component }}
{{- $value := default "" .value }}
{{- $values := split "__" $value }}
{{- if eq (len $values) 0 }}
  {{- $value }}
{{- else }}
  {{- if eq (index $values 2) "postgres" }}
    {{- if eq (index $values 3) "host" }}
      {{- if eq (index $values 1) "addons" }}
        {{ include "commons.fullname" (dict "Chart" $.Chart "Values" $.Values "Release" $.Release "name" .name) }}-rw
      {{- else if eq (index $values 1) "components" }}
        {{ include "commons.fullname" (dict "Chart" $.Chart "Values" $.Values "Release" $.Release "name" .name "component" $component) }}-rw
      {{- else }}
        {{- $value }}
      {{- end }}
    {{- else if eq (index $values 3) "username" }}
      {{- if eq (index $values 1) "addons" }}
        {{- .Values.addons.postgres.cluster.username }}
      {{- else if eq (index $values 1) "components" }}
        {{- $component.postgres.cluster.username }}
      {{- else }}
        {{- $value }}
      {{- end }}
    {{- else if eq (index $values 3) "password" }}
      {{- if eq (index $values 1) "addons" }}
        {{ include "commons.fullname" (dict "Chart" $.Chart "Values" $.Values "Release" $.Release "name" .name) }}-secret
      {{- else if eq (index $values 1) "components" }}
        {{ include "commons.fullname" (dict "Chart" $.Chart "Values" $.Values "Release" $.Release "name" .name "component" $component) }}-secret
      {{- else }}
        {{- $value }}
      {{- end }}
    {{- else }}
      {{- $value }}
    {{- end }}
  {{- else if eq (index $values 2) "pvc" }}
    {{- if eq (index $values 1) "components" }}
      {{ include "commons.fullname" (dict "Chart" $.Chart "Values" $.Values "Release" $.Release "name" (index $values 3) "component" $component) }}
    {{- else }}
      {{- $value }}
    {{- end }}
  {{- else }}
    {{- $value }}
  {{- end }}
{{- end }}
{{- end }}