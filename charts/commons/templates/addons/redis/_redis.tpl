{{- /*
Ce bloc ajoute l'addon Redis à la liste des addons si :
- Redis est activé dans les valeurs
- Redis n'est pas déjà présent dans la liste des addons
*/ -}}

{{- $addons := $addons | default list }}
{{- $base := $addons }}
{{- $names := pluck "name" $base }}
{{- $hasRedis := has "redis" $names }}

{{- if and .Values.addons.redis.enable (not $hasRedis) }}

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

  {{- $raw := .Values.addons.redis | default dict }}
  {{- $overrides := omit $raw "enable" "name" }}
  {{- $redis := merge $defaults $overrides }}
  {{- $_ := set $redis "name" "redis" }}  {{/* force le nom */}}

  {{- $addons = append $addons $redis }}

{{- end }}
