{{- define "commons.addon.redis" }}
{{- if .Values.addons.redis.enabled }}
  {{- $defaults := dict
    "name" "redis"
    "deployment" (dict
      "name" "redis"
      "image" .Values.addons.redis.image.repository
      "tag" .Values.addons.redis.image.tag
      "ports" (list (dict "name" "redis" "containerPort" 6379))
      "env" (list
        (dict
          "name" "REDIS_PASSWORD"
          "valueFrom" (dict
            "secretKeyRef" (dict
              "name" "redis-secret"
              "key" "password"
            )
          )
        )
      )
      "livenessProbe" (dict
        "tcpSocket" (dict "port" 6379)
        "initialDelaySeconds" 5
        "periodSeconds" 10
      )
      "readinessProbe" (dict
        "tcpSocket" (dict "port" 6379)
        "initialDelaySeconds" 5
        "periodSeconds" 10
      )
    )
    "service" (dict
      "enabled" true
      "type" "ClusterIP"
      "ports" (list (dict "name" "redis" "port" 6379))
    )
  }}
  {{- $redis := .Values.addons.redis | default dict }}
  {{- toYaml $redis }}
{{- end }}
{{- end }}
