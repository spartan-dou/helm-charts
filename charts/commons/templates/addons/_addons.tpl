{{- define "commons.withAddons" }}
{{- $base := .Values.components | default list }}
{{- $addons := list }}

{{/* === Addon VSCode === */}}
{{- if and .Values.addons.vscode.enabled }}
  {{- $defaults := dict
    "name" "vscode"
    "deployment" (dict
      "name" "code-server"
      "image" "codercom/code-server"
      "tag" "latest"
      "ports" (list (dict "name" "http" "containerPort" 8080))
      "volumeMounts" (list (dict "name" "vscode-data" "mountPath" "/home/coder/project"))
      "volumes" (list (dict "name" "vscode-data" "emptyDir" (dict)))
    )
    "service" (dict
      "enabled" true
      "type" "ClusterIP"
      "ports" (list (dict "name" "http" "port" 8080))
    )
  }}
  {{- $raw := .Values.addons.vscode | default dict }}
  {{- $overrides := omit $raw "enable" }}
  {{- $vscode := merge $defaults $overrides }}
  {{- $addons = append $addons $vscode }}
{{- end }}

{{/* === Addon Redis === */}}
{{- if and .Values.addons.redis.enabled }}
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
  {{- $addons = append $addons $redis }}
{{- end }}

{{/* === Fusion finale === */}}
{{- $all := concat $base $addons }}
{{- toYaml $all }}
{{- end }}
