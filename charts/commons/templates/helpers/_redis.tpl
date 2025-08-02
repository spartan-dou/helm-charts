{{- $base := .Values.components | default list }}
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