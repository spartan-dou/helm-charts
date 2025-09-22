{{- define "commons.withAddons" }}
{{- $base := .Values.components | default list }}
{{- $addons := list }}

{{/* === Addon VSCode === */}}
{{- if .Values.addons.vscode.enabled }}
  {{- $defaults := dict
    "name" "code-server"
    "deployment" (dict
      "image" (dict
        "repository" .Values.addons.vscode.image.repository
        "tag" .Values.addons.vscode.image.tag | default "latest"
      )
      "ports" (list (dict "name" "http" "containerPort" .Values.addons.vscode.port))
      "volumeMounts" (list (dict "name" "vscode-data" "mountPath" "/home/coder/project"))
      "volumes" (list (dict
        "name" "vscode-data"
        "persistentVolumeClaim" (dict "claimName" "vscode-data")
      ))
    )
    "pvc" (list (dict
      "name" "vscode-data"
      "storage" "1Gi"
      "storageClassName" (default .Values.global.pvc.storage.storageClassName .Values.addons.vscode.storageClassName)
    ))
    "service" (dict
      "enabled" true
      "type" "ClusterIP"
      "ports" (list (dict "name" "http" "port" .Values.addons.vscode.port))
    )
  }}
  {{- if (default dict (default dict .Values.addons.vscode).ingress).enabled }}
  {{- /* dictionnaire ingress par défaut */ -}}
  {{- $ingressDefaults := dict
      "enabled" true
  }}

  {{- /* valeurs utilisateur depuis values.yaml */ -}}
  {{- $ingressOverrides := default dict .Values.addons.vscode.ingress }}

  {{- /* on enlève la clé enabled pour ne pas écraser la condition */ -}}
  {{- $ingressOverrides := omit $ingressOverrides "enabled" }}

  {{- /* fusion defaults + overrides */ -}}
  {{- $_ := set $defaults "ingress" (merge $ingressDefaults $ingressOverrides) }}
  {{- end }}
  {{- $raw := .Values.addons.vscode | default dict }}
  {{- $overrides := omit $raw "enabled" }}
  {{- $vscode := merge $defaults $overrides }}
  {{- $addons = append $addons $vscode }}
{{- end }}

{{/* === Addon Redis === */}}
{{- if .Values.addons.redis.enabled }}
  {{- $defaults := dict
    "name" "redis"
    "deployment" (dict
      "image" (dict
        "repository" .Values.addons.redis.image.repository
        "tag" .Values.addons.redis.image.tag | default "latest"
      )
      "ports" (list (dict "name" "redis" "containerPort" .Values.addons.redis.port))
      "livenessProbe" (dict
        "tcpSocket" (dict "port" .Values.addons.redis.port)
        "initialDelaySeconds" 5
        "periodSeconds" 10
      )
      "readinessProbe" (dict
        "tcpSocket" (dict "port" .Values.addons.redis.port)
        "initialDelaySeconds" 5
        "periodSeconds" 10
      )
      "volumeMounts" (list (dict
        "mountPath" (default "/data" (default dict .Values.addons.redis.storage).mountPath)
        "name" "data"
      ))
      "volumes" (list (dict
        "name" "data"
        "persistentVolumeClaim" (dict "claimName" (printf "%s-redis-data" $.Release.Name))
      ))
    )
    "pvc" (list (dict
      "name" "data"
      "storage" (default .Values.global.pvc.storage.size (default dict .Values.addons.redis.storage).size)
      "storageClassName" (default .Values.global.pvc.storage.storageClassName (default dict .Values.addons.redis.storage).storageClassName)
    ))
    "service" (dict
      "enabled" true
      "type" "ClusterIP"
      "ports" (list (dict "name" "redis" "port" .Values.addons.redis.port))
    )
  }}
  {{- $raw := .Values.addons.redis | default dict }}
  {{- $overrides := omit $raw "enabled" "name" }}
  {{- $redis := merge $defaults $overrides }}
  {{- $addons = append $addons $redis }}
{{- end }}

{{/* === Addon PGadmin === */}}
{{- if .Values.addons.pgAdmin.enabled }}
  {{- $defaults := dict
    "name" "pgAdmin"
    "deployment" (dict
      "image" (dict
        "repository" .Values.addons.pgAdmin.image.repository
        "tag" (default "latest" .Values.addons.pgAdmin.image.tag)
      )
      "env" (list
        (dict "name" "PGADMIN_CONFIG_MASTER_PASSWORD_REQUIRED" "value" "False")
        (dict "name" "PGPASS_FILE" "value" "/pgpass")
        (dict "name" "PGADMIN_CONFIG_SERVER_MODE" "value" "False")
      )
      "ports" (list (dict "name" "pgAdmin" "containerPort" .Values.addons.pgAdmin.port))
      "livenessProbe" (dict
        "tcpSocket" (dict "port" .Values.addons.pgAdmin.port)
        "initialDelaySeconds" 5
        "periodSeconds" 10
      )
      "readinessProbe" (dict
        "tcpSocket" (dict "port" .Values.addons.pgAdmin.port)
        "initialDelaySeconds" 5
        "periodSeconds" 10
      )
      "volumeMounts" (list
        (dict "mountPath" "/pgadmin4/servers.json" "subPath" "servers.json" "name" "config")
        (dict "mountPath" "/pgpass" "subPath" "pgpass" "name" "config")
      )
      "volumes" (list
        (dict
          "name" "config"
          "configMap" (dict
            "name" (include "commons.getValue" (dict
              "Values" $.Values
              "Chart" $.Chart
              "Release" $.Release
              "component" (dict
                "configMap" (list (dict
                  "name" "pg-config"
                ))
                "name" "pgAdmin"
              )
              "value" "__components__configmap__pg-config"
            ))
          )
        )
      )
    )
    "configMap" (list (dict
      "name" "pg-config"
      "data" (dict
        "server.json" (indent 4 (tpl (.Files.Get "files/pgadmin/servers.json") .))
        "pgpass" (indent 4 (tpl (.Files.Get "files/pgadmin/pgpass") .))
      )
    ))
    "service" (dict
      "enabled" true
      "type" .Values.addons.pgAdmin.service.type
      "ports" (list (dict "name" "pgAdmin" "port" .Values.addons.pgAdmin.port))
    )
  }}
  {{- $ingressOverrides := default dict .Values.addons.pgAdmin.ingress }}
  {{- $ingressOverrides := omit $ingressOverrides "enabled" }}
  {{- $_ := set $defaults "ingress" (merge (dict "enabled" true) $ingressOverrides) }}
  {{- $raw := .Values.addons.pgAdmin | default dict }}
  {{- $overrides := omit $raw "enabled" "name" }}
  {{- $pgAdmin := merge $defaults $overrides }}
  {{- $addons = append $addons $pgAdmin }}
{{- end }}

{{/* === Fusion finale === */}}
{{- $all := concat $base $addons }}
{{- toYaml $all }}
{{- end }}
