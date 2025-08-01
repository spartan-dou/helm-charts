{{/*
  Récupère le nom du chart (peut être surchargé par .Values.nameOverride)
*/}}
{{- define "commons.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
  Génère un nom complet (fullname) pour les ressources déployées
*/}}
{{- define "commons.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
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

{{- define "commons.redisInitContainer" -}}
{{- $enabled := .Values.addons.redis.enable }}
{{- $hasSecret := .Values.addons.redis.existingSecret }}
{{- $password := .Values.addons.redis.password | default "" }}
{{- $component := .component | default "" }}

{{- if and $enabled (not $hasSecret) (ne $component "redis") }}
- name: wait-for-redis
  image: redis:7
  command:
    - sh
    - -c
    - >
      {{- if ne $password "" }}
      until redis-cli -h redis -a "$REDIS_PASSWORD" ping | grep PONG;
      do echo waiting for redis; sleep 2; done
      {{- else }}
      until redis-cli -h redis ping | grep PONG;
      do echo waiting for redis; sleep 2; done
      {{- end }}
  {{- if ne $password "" }}
  env:
    - name: REDIS_PASSWORD
      valueFrom:
        secretKeyRef:
          name: {{ include "commons.fullname" (dict "Chart" .Chart "Values" .Values "Release" .Release "name" "redis") }}-secret
          key: password
  {{- end }}
{{- end }}
{{- end }}

