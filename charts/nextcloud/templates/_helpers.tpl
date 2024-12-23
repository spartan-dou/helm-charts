{{/*
Expand the name of the chart.
*/}}
{{- define "nextcloud.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "nextcloud.fullname" -}}
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
Create chart name and version as used by the chart label.
*/}}
{{- define "nextcloud.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "nextcloud.labels" -}}
helm.sh/chart: {{ include "nextcloud.chart" . }}
{{ include "nextcloud.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "nextcloud.selectorLabels" -}}
app.kubernetes.io/name: {{ include "nextcloud.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "nextcloud.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "nextcloud.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Create volume mounts for the nextcloud container as well as the cron sidecar container.
*/}}
{{- define "nextcloud.volumeMounts" -}}
- name: nextcloud
  mountPath: /var/www/html
  subPath: html
- name: nextcloud-data
  mountPath: {{ .Values.nextcloud.persistence.data.dir }}
- name: nextcloud
  mountPath: /var/www/html/config
  subPath: config
- name: nextcloud
  mountPath: /var/www/html/custom_apps
  subPath: custom_apps
- name: nextcloud
  mountPath: /var/www/tmp
  subPath: tmp
- name: nextcloud
  mountPath: /var/www/html/themes
  subPath: themes
{{- end }}

{{/*
Create env-variable for the nextcloud container as well as the cron sidecar container.
*/}}
{{- define "nextcloud.env" -}}
- name: NEXTCLOUD_ADMIN_USER
  valueFrom:
    secretKeyRef:
      name: {{ .Release.Name }}-secret
      key: username
- name: NEXTCLOUD_ADMIN_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ .Release.Name }}-secret
      key: password
{{- if .Values.postgresql.enabled }}
- name: POSTGRES_HOST
  value: {{ .Release.Name }}-cnpg-rw
- name: POSTGRES_DB
  value: nextcloud
- name: POSTGRES_USER
  value: nextcloud
- name: POSTGRES_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ .Release.Name }}-db-secret
      key: password
{{- else }}
- name: SQLITE_DATABASE
  value: nextcloud
{{- end }}
- name: NEXTCLOUD_UPDATE
  value: {{ .Values.nextcloud.apps.update | quote }}
- name: NEXTCLOUD_DATA_DIR
  value: {{ .Values.nextcloud.persistence.data.dir | quote }}
- name: REDIS_HOST
  value: {{ .Release.Name }}-redis-master
- name: REDIS_HOST_PORT
  value: "6379"
- name: REDIS_HOST_PASSWORD
  value: {{ .Values.redis.global.redis.password }}
{{- if .Values.nextcloud.smtp.enabled }}
- name: MAIL_FROM_ADDRESS
  value: {{ .Values.nextcloud.smtp.fromAddress | quote }}
- name: MAIL_DOMAIN
  value: {{ .Values.nextcloud.smtp.mailDomain | quote }}
- name: SMTP_SECURE
  value: {{ .Values.nextcloud.smtp.secure | quote }}
- name: SMTP_PORT
  value: {{ .Values.nextcloud.smtp.port | quote }}
- name: SMTP_AUTHTYPE
  value: {{ .Values.nextcloud.smtp.authtype | quote }}
- name: SMTP_HOST
  value: {{ .Values.nextcloud.smtp.host | quote }}
- name: SMTP_NAME
  value: {{ .Values.nextcloud.smtp.name | quote }}
- name: SMTP_PASSWORD
  value: {{ .Values.nextcloud.smtp.password | quote }}
{{- end }}
- name: OVERWRITEPROTOCOL
  value: {{ .Values.nextcloud.overwriteprotocol | quote }}
- name: OVERWRITECLIURL
  value: https://{{ .Values.nextcloud.host }}
- name: TRUSTED_PROXIES
  {{- if .Values.nextcloud.trustedProxies }}
  value: {{ join " " .Values.nextcloud.trustedProxies | quote }}
  {{- end }}
- name: NEXTCLOUD_TRUSTED_DOMAINS
  {{- if .Values.nextcloud.trustedDomains }}
  value: {{ join " " .Values.nextcloud.trustedDomains | quote }}
  {{- else }}
  value: {{ .Values.nextcloud.host }}
  {{- end }}
- name: PHP_MEMORY_LIMIT
  value: {{ .Values.nextcloud.php.memoryLimit | quote }}
- name: PHP_UPLOAD_LIMIT
  value: {{ .Values.nextcloud.php.uploadLimit | quote }}
{{- end }}