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
    {{ $host := include "commons.getValue" (dict "Values" $.Values "Chart" $.Chart "Release" $.Release "value" "__addons__redis__host") }}
    {{- $redisInit := dict
      "name" "wait-for-redis"
      "image" (dict
        "repository" $.Values.addons.redis.image.repository
        "tag" $.Values.addons.redis.image.tag
      )
      "command" (list "sh" "-c" (printf "until redis-cli -h %s ping | grep PONG; do echo waiting for redis; sleep 2; done" $host))
    }}
    {{- $merged = append $merged $redisInit }}
  {{- end }}

  {{- if $.Values.addons.postgres.enabled }}
    {{- $postgresInit := dict
      "name" "wait-for-postgres"
      "image" (dict
        "repository" $.Values.addons.postgres.image.repository
        "tag" $.Values.addons.postgres.image.tag
      )
      "command" (list "sh" "-c" (printf "until pg_isready -h %s -p %s -U %s; do echo \"Waiting for Postgres to be ready...\"; sleep 2; done" (include "postgres.host" $) "5432" (include "postgres.username" $)))
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

  {{- if $c.cronjobs }}
    {{- range $cj := $c.cronjobs }}
      {{- $existingCronjob := $cj.initContainers | default list }}
      {{- $mergedCronjob := list }}
      {{- range $existingCronjob }}
        {{- $mergedCronjob = append $mergedCronjob . }}
      {{- end }}

      {{- if $.Values.addons.redis.enabled }}
        {{ $host := include "commons.getValue" (dict "Values" $.Values "Chart" $.Chart "Release" $.Release "value" "__addons__redis__host") }}
        {{- $redisInit := dict
          "name" "wait-for-redis"
          "image" (dict
            "repository" $.Values.addons.redis.image.repository
            "tag" $.Values.addons.redis.image.tag
          )
          "command" (list "sh" "-c" (printf "until redis-cli -h %s ping | grep PONG; do echo waiting for redis; sleep 2; done" $host))
        }}
        {{- $mergedCronjob = append $mergedCronjob $redisInit }}
      {{- end }}

      {{- if $.Values.addons.postgres.enabled }}
        {{- $postgresInit := dict
          "name" "wait-for-postgres"
          "image" (dict
            "repository" $.Values.addons.postgres.image.repository
            "tag" $.Values.addons.postgres.image.tag
          )
          "command" (list "sh" "-c" (printf "until pg_isready -h %s -p %s -U %s; do echo \"Waiting for Postgres to be ready...\"; sleep 2; done" (include "postgres.host" $) "5432" (include "postgres.username" $)))
          "resources" (dict
            "requests" (dict "cpu" "10m" "memory" "16Mi")
            "limits"   (dict "cpu" "50m" "memory" "32Mi")
          )
        }}
        {{- $mergedCronjob = append $mergedCronjob $postgresInit }}
      {{- end }}

      {{- $_ := set $cj "initContainers" $mergedCronjob }}
    {{- end }}
  {{- end }}

  {{- $result = append $result $c }}
{{- end }}

{{- $addons := list }}

{{/* === Addon VSCode === */}}
{{- if .Values.addons.vscode.enabled }}

  {{/* VolumeMounts */}}
  {{- $volumeMounts := list (dict "name" "vscode-config" "mountPath" "/config") }}
  {{- range .Values.addons.vscode.volumes }}
  {{- $volumeMounts = append $volumeMounts (dict "name" .name "mountPath" (print "/config/workspace/" .name) ) }}
  {{- end }}

  {{/* Volumes */}}
  {{- $volumes := list (dict
    "name" "vscode-config"
    "pvc" (dict
      "name" "vscode-config"
      "storage" (dict
        "size" "1Gi"
        "storageClassName" (default .Values.global.pvc.storage.storageClassName .Values.addons.vscode.storageClassName)
      )
    )
  )}}

  {{- range .Values.addons.vscode.volumes }}
    {{- $vol := dict "name" .name }}
    {{- with .pvc }}
      {{- $storage := dict }}
      {{- with .storage }}
        {{- $storage = dict
          "size" (default $.Values.global.pvc.storage.size .size)
          "storageClassName" (default $.Values.global.pvc.storage.storageClassName $.Values.addons.vscode.storageClassName)
        }}
      {{- end }}
      {{- $vol = merge $vol (dict "pvc" (merge (dict "name" .name "useExisting" (default true .useExisting)) (dict "storage" $storage))) }}
    {{- end }}
    {{- $volumes = append $volumes $vol }}
  {{- end }}

  {{- $defaults := dict
      "name" "code-server"
      "deployment" (dict
        "containers" (list (dict
            "image" (dict
                "repository" .Values.addons.vscode.image.repository
                "tag" (default "latest" .Values.addons.vscode.image.tag)
            )
            "securityContext": {{ merge (dict "runAsUser" 1000 "runAsGroup" 1000 "fsGroup" 1000) (.Values.addons.vscode.securityContext | default dict) | toYaml | nindent 14 }}
            "env" (list (dict "name" "DEFAULT_WORKSPACE" "value" "/config/workspace"))
            "volumeMounts" $volumeMounts
        ))
      "volumes" $volumes
      )
      "service" (dict
          "type" (default "ClusterIP" .Values.addons.vscode.service.type)
          "ports" (list (dict "name" "http" "port" .Values.addons.vscode.service.port))
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
      "containers" (list (dict
        "image" (dict
            "repository" .Values.addons.redis.image.repository
            "tag" .Values.addons.redis.image.tag | default "latest"
        )
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
      ))
    "volumes" (list (dict
      "name" "data"
      "pvc" (dict 
        "name" (printf "data")
        "storage" (dict
          "size" (default .Values.global.pvc.storage.size (default dict .Values.addons.redis.storage).size)
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

{{/* === Addon pgadmin === */}}
{{- if .Values.addons.pgadmin.enabled }}
  {{- $defaults := dict
    "name" "pgadmin"
    "deployment" (dict
      "containers" (list (dict
          "image" (dict
              "repository" .Values.addons.pgadmin.image.repository
              "tag" (default "latest" .Values.addons.pgadmin.image.tag)
          )
        "env" (list
          (dict "name" "PGPASS_FILE" "value" "/pgadmin4/pgpass")
          (dict "name" "PGADMIN_DEFAULT_EMAIL" "value" .Values.addons.pgadmin.auth.email)
          (dict "name" "PGADMIN_DEFAULT_PASSWORD" "value" .Values.addons.pgadmin.auth.password)
        )
        "securityContext" (dict
          "runAsUser" 5050
          "runAsGroup" 5050
          "fsGroup" 5050
          "runAsNonRoot" true
          "readOnlyRootFilesystem" false
        )
        "livenessProbe" (dict
          "tcpSocket" (dict "port" .Values.addons.pgadmin.service.port)
          "initialDelaySeconds" 5
          "periodSeconds" 10
        )
        "readinessProbe" (dict
          "tcpSocket" (dict "port" .Values.addons.pgadmin.service.port)
          "initialDelaySeconds" 5
          "periodSeconds" 10
        )
        "volumeMounts" (list
        (dict "mountPath" "/pgadmin4/servers.json" "subPath" "servers.json" "name" "config")
        (dict "mountPath" "/pgadmin4/pgpass" "subPath" "pgpass" "name" "config")
      )
      ))
    "volumes" (list
        (dict
          "name" "config"
          "configMap" (dict
            "name" "pg-config"
            "data" (dict
              "servers.json" (trim (include "pgadmin.servers" (dict "Values" $.Values "Chart" $.Chart "Release" $.Release)))
              "pgpass" (trim (include "pgadmin.pgpass" (dict "Values" $.Values "Chart" $.Chart "Release" $.Release)))
            ))
        )
      )
    )
    "service" (dict
      "enabled" true
      "type" .Values.addons.pgadmin.service.type
      "ports" (list (dict "name" "pgadmin" "port" .Values.addons.pgadmin.service.port))
    )
    "ingress" (toYaml .Values.addons.pgadmin.ingress | fromYaml)
  }}
  {{- $raw := .Values.addons.pgadmin | default dict }}
  {{- $overrides := omit $raw "enabled" "name" }}
  {{- $pgadmin := merge $defaults $overrides }}
  {{- $addons = append $addons $pgadmin }}
{{- end }}

{{/* === Fusion finale === */}}
{{- $all := concat $result $addons }}
{{- toYaml $all }}
{{- end }}
