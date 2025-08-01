{{- if and .Values.addons.redis.enable (not (has "redis" (pluck "name" $base | flatten))) }}

{{- $defaults := dict
  "name" "redis"
  "deployment" (dict
    "name" "redis"
    "image" "bitnami/redis"
    "tag" "latest"
    "ports" (list (dict "name" "redis" "containerPort" 6379))
    "env" (list
      (dict
        "name" "REDIS_PASSWORD"
        "valueFrom" (dict
          "secretKeyRef" (dict
            "name" (printf "%s-secret" "redis")
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
) }}

{{- $raw := .Values.addons.redis | default dict }}
{{- $overrides := omit $raw "enable" }}
{{- $redis := merge $defaults $overrides }}

{{- $addons = append $addons $redis }}
{{- end }}
