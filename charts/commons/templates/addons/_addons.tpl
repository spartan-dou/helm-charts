{{- define "commons.withAddons" }}
{{- $base := .Values.components | default list }}
{{- $addons := list }}

{{/* === Addon VSCode === */}}
{{- if .Values.addons.vscode.enabled }}
  {{- $defaults := dict
    "name" "vscode"
    "deployment" (dict
      "name" "code-server"
      "image" $.Values.addons.vscode.image.repository
      "tag" $.Values.addons.vscode.image.tag
      "ports" (list (dict "name" "http" "containerPort" $.Values.addons.vscode.port))
      "volumeMounts" (list (dict "name" "vscode-data" "mountPath" "/home/coder/project"))
      "volumes" (list (dict "name" "vscode-data" "emptyDir" (dict)))
    )
    "service" (dict
      "enabled" true
      "type" "ClusterIP"
      "ports" (list (dict "name" "http" "port" $.Values.addons.vscode.port))
    )
  }}
  {{- $raw := .Values.addons.vscode | default dict }}
  {{- $overrides := omit $raw "enable" }}
  {{- $vscode := merge $defaults $overrides }}
  {{- $addons = append $addons $vscode }}
{{- end }}

{{/* === Addon Redis === */}}
{{- if .Values.addons.redis.enabled }}
  {{- $defaults := dict
    "name" "redis"
    "deployment" (dict
      "name" "redis"
      "image" $.Values.addons.redis.image.repository
      "tag" $.Values.addons.redis.image.tag
      "ports" (list (dict "name" "redis" "containerPort" $.Values.addons.redis.port))
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
        "tcpSocket" (dict "port" $.Values.addons.redis.port)
        "initialDelaySeconds" 5
        "periodSeconds" 10
      )
      "readinessProbe" (dict
        "tcpSocket" (dict "port" $.Values.addons.redis.port)
        "initialDelaySeconds" 5
        "periodSeconds" 10
      )
    )
    "service" (dict
      "enabled" true
      "type" "ClusterIP"
      "ports" (list (dict "name" "redis" "port" $.Values.addons.redis.port))
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
