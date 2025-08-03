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
          name: {{ include "commons.fullname" (dict "Chart" $values.Chart "Values" $values "Release" $values.Release "name" "redis") }}-secret
          key: password
  {{- end }}
{{- end }}
