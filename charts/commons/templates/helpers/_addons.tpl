{{- define "commons.withAddons" }}
{{- $base := deepCopy (.Values.components | default list) }}
{{- $result := list }}

{{- range $i, $c := $base }}
  {{- $existing := $c.deployment.initContainers | default list }}
  {{- $merged := list }}
  {{- range $existing }}
    {{- $merged = append $merged . }}
  {{- end }}

  {{- if $.Values.addons.redis.enabled }}
    {{- $redisInit := dict
      "name" "wait-for-redis"
      "image" (dict
        "repository" $.Values.addons.redis.image.repository
        "tag" $.Values.addons.redis.image.tag
      )
      "command" (list "sh" "-c" "until redis-cli -h redis ping | grep PONG; do echo waiting for redis; sleep 2; done")
    }}
    {{- $merged = append $merged $redisInit }}
  {{- end }}

  {{- if $.Values.addons.postgres.enabled }}
    {{- $name := $.Values.addons.postgres.name }}
    {{- $image := $.Values.addons.postgres.image.repository }}
    {{- $tag := $.Values.addons.postgres.image.tag }}
    {{- $host := include "postgres.host" $ }}
    {{- $port := "5432" }}
    {{- $user := include "postgres.username" $ }}

    {{- $postgresInit := dict
      "name" (printf "wait-for-postgres")
      "image" (dict
        "repository" $image
        "tag" $tag
      )
      "command" (list "sh" "-c" (printf "until pg_isready -h %s -p %s -U %s; do echo \"Waiting for Postgres to be ready...\"; sleep 2; done" $host $port $user))
      "resources" (dict
        "requests" (dict "cpu" "10m" "memory" "16Mi")
        "limits"   (dict "cpu" "50m" "memory" "32Mi")
      )
    }}
    {{- $merged = append $merged $postgresInit }}
  {{- end }}

  {{- if and $c.postgres $c.postgres.enabled }}
    {{- $image := $c.image | default $.Values.addons.postgres.image.repository }}
    {{- $tag := $c.tag | default $.Values.addons.postgres.image.tag }}
    {{- $host := include "commons.getValue" (dict "Values" $.Values "Chart" $.Chart "Release" $.Release "component" $c "value" "__components__postgres__host") }}
    {{- $user := include "commons.getValue" (dict "Values" $.Values "Chart" $.Chart "Release" $.Release "component" $c "value" "__components__postgres__username") }}
    {{- $postgresInit := dict
      "name" (printf "wait-for-postgres-%s" $c.name)
      "image" (dict
        "repository" $image
        "tag" $tag
      )
      "command" (list "sh" "-c" (printf "until pg_isready -h %s -p %s -U %s; do echo \"Waiting for Postgres to be ready...\"; sleep 2; done" $host "5432" $user))
      "resources" (dict
        "requests" (dict "cpu" "10m" "memory" "16Mi")
        "limits"   (dict "cpu" "50m" "memory" "32Mi")
      )
    }}
    {{- $merged = append $merged $postgresInit }}
  {{- end }}

  {{- $_ := set $c.deployment "initContainers" $merged }}
  {{- $result = append $result $c }}

{{- end }}

{{- $addons := list }}

{{/* === Addon VSCode === */}}
{{- if .Values.addons.vscode.enabled }}

  {{/* VolumeMounts */}}
  {{- $volumeMounts := list (dict "name" "vscode-data" "mountPath" "/home/coder/project") }}
  {{- range .Values.addons.vscode.volumes }}
    {{- $name := .name }}
    {{- with .volumeMount }}
      {{- $volumeMounts = append $volumeMounts (dict "name" $name "mountPath" .mountPath) }}
    {{- end }}
  {{- end }}

  {{/* Volumes */}}
  {{- $volumes := list (dict
    "name" "vscode-data"
    "pvc" (dict
      "name" "vscode-data"
      "spec" (dict
        "storage" "1Gi"
        "storageClassName" (default .Values.global.pvc.storage.storageClassName .Values.addons.vscode.storageClassName)
      )
    )
  ) }}

  {{- range .Values.addons.vscode.volumes }}
    {{- $vol := dict "name" .name }}
    {{- with .pvc }}
      {{- $spec := dict }}
      {{- with .spec }}
        {{- $spec = dict
          "storage" (default $.Values.global.pvc.storage.size .size)
          "storageClassName" (default $.Values.global.pvc.storage.storageClassName $.Values.addons.vscode.storageClassName)
        }}
      {{- end }}
      {{- $vol = merge $vol (dict "pvc" (merge (dict "name" .name "useExisting" (default true .useExisting)) (dict "spec" $spec))) }}
    {{- end }}
    {{- $volumes = append $volumes $vol }}
  {{- end }}

  {{- $defaults := dict
    "name" "code-server"
    "deployment" (dict
      "image" (dict
        "repository" .Values.addons.vscode.image.repository
        "tag" (default "latest" .Values.addons.vscode.image.tag)
      )
      "ports" (list (dict "name" "http" "containerPort" .Values.addons.vscode.port))
      "volumeMounts" $volumeMounts
      "volumes" $volumes 
    )
    "service" (dict
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
        "pvc" (dict 
          "name" (printf "data")
          "spec" (dict
            "storage" (default .Values.global.pvc.storage.size (default dict .Values.addons.redis.storage).size)
            "storageClassName" (default .Values.global.pvc.storage.storageClassName (default dict .Values.addons.redis.storage).storageClassName)
          ))
      ))
    )
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
            "name" "pg-config"
            "spec" (dict
              "data" (dict
                "server.json" (trim (include "pgadmin.servers" (dict "Values" $.Values "Chart" $.Chart "Release" $.Release)))
                "pgpass" (trim (include "pgadmin.pgpass" (dict "Values" $.Values "Chart" $.Chart "Release" $.Release)))
              ))
          )
        )
      )
    )
    "service" (dict
      "enabled" true
      "type" .Values.addons.pgAdmin.service.type
      "ports" (list (dict "name" "pgAdmin" "port" .Values.addons.pgAdmin.port))
    )
    "ingress" (toYaml .Values.addons.pgAdmin.ingress | fromYaml)
  }}
  {{- $raw := .Values.addons.pgAdmin | default dict }}
  {{- $overrides := omit $raw "enabled" "name" }}
  {{- $pgAdmin := merge $defaults $overrides }}
  {{- $addons = append $addons $pgAdmin }}
{{- end }}

{{/* === Fusion finale === */}}
{{- $all := concat $result $addons }}
{{- toYaml $all }}
{{- end }}
