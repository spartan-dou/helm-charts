{{- define "commons.redisInitContainer" -}}
{{- $enabled := .Values.addons.redis.enabled }}
{{- $hasSecret := .Values.addons.redis.existingSecret }}
{{- $password := .Values.addons.redis.password | default "" }}
{{- $component := .component | default "" }}

{{- if and $enabled }}
name: wait-for-redis
image: {{ .Values.addons.redis.image.repository }}:{{ .Values.addons.redis.image.tag | default "latest" }}
command:
  - sh
  - -c
  - |-
    until redis-cli -h redis ping | grep PONG;
    do echo waiting for redis; sleep 2; done
{{- end }}

{{- end }}
