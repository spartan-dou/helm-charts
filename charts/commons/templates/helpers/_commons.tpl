{{/*
  Récupère le nom du chart (peut être surchargé par .Values.nameOverride)
*/}}
{{- define "commons.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
  Génère un nom complet (fullname) pour les ressources déployées
  - Ignore .Chart.Name si c'est "commons"
  - Ajoute .Values.name en suffixe si défini
*/}}
{{- define "commons.fullname" -}}
{{- $component := .component | default "" }}
{{- if .Values.fullnameOverride }}
  {{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
  {{- /* Détermine le nom de base : nameOverride ou Chart.Name */ -}}
  {{- $baseName := default .Chart.Name .Values.nameOverride }}

  {{- /* Si le chart s'appelle "commons", on ignore ce nom */ -}}
  {{- if eq $baseName "commons" }}
    {{- $baseName = "" }}
  {{- end }}

  {{- /* Construit le nom complet */ -}}
  {{- $full := "" }}
  {{- if and $baseName (not (contains $baseName .Release.Name)) }}
    {{- $full = printf "%s-%s" .Release.Name $baseName }}
  {{- else }}
    {{- $full = .Release.Name }}
  {{- end }}

  {{- /* Ajoute le suffixe componentName si défini */ -}}
  {{- $name := .component.deployment.name | default .component.name }}
  {{- $full = printf "%s-%s" $full $name }}

  {{- /* Ajoute le suffixe name si défini */ -}}
  {{- if .name }}
    {{- $full = printf "%s-%s" $full .name }}
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
app: {{ .name }}
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