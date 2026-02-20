{{- define "commons.withAddons" }}
{{- $base := deepCopy (.Values.components | default list) }}
{{- $result := list }}

{{- range $i, $c := $base }}
  {{- $merged := $c.deployment.initContainers | default list }}

  {{- if $.Values.addons.redis.enabled }}
    {{- $host := include "commons.getValue" (dict "Values" $.Values "Chart" $.Chart "Release" $.Release "value" "__addons__redis__host") }}
    {{- $redisInit := dict
      "name" "wait-for-redis"
      "image" (dict
        "repository" $.Values.addons.redis.image.repository
        "tag" ($.Values.addons.redis.image.tag | default "latest")
      )
      "command" (list "sh" "-c" (printf "until redis-cli -h %s ping | grep PONG; do echo waiting for redis; sleep 2; done" $host))
      "resources" (dict
        "requests" (dict "cpu" "10m" "memory" "16Mi")
        "limits"   (dict "cpu" "50m" "memory" "32Mi")
      )
    }}
    {{- $merged = append $merged $redisInit }}
  {{- end }}

  {{- if $.Values.addons.postgres.enabled }}
    {{- $postgresInit := dict
      "name" "wait-for-postgres"
      "image" (dict
        "repository" $.Values.addons.postgres.image.repository
        "tag" ($.Values.addons.postgres.image.tag | default "latest")
      )
      "command" (list "sh" "-c" (printf "until pg_isready -h %s -p %s -U %s; do echo \"Waiting for Postgres...\"; sleep 2; done" (include "postgres.host" $) "5432" (include "postgres.username" $)))
      "resources" (dict
        "requests" (dict "cpu" "10m" "memory" "16Mi")
        "limits"   (dict "cpu" "50m" "memory" "32Mi")
      )
    }}
    {{- $merged = append $merged $postgresInit }}
  {{- end }}

  {{- if and $c.postgres $c.postgres.enabled }}
    {{- $host := include "commons.getValue" (dict "Values" $.Values "Chart" $.Chart "Release" $.Release "component" $c "value" "__components__postgres__host") }}
    {{- $user := include "commons.getValue" (dict "Values" $.Values "Chart" $.Chart "Release" $.Release "component" $c "value" "__components__postgres__username") }}
    {{- $postgresInit := dict
      "name" (printf "wait-for-postgres-%s" $c.name)
      "image" (dict
        "repository" (default $.Values.addons.postgres.image.repository $c.image)
        "tag" (default $.Values.addons.postgres.image.tag $c.tag)
      )
      "command" (list "sh" "-c" (printf "until pg_isready -h %s -p %s -U %s; do echo \"Waiting for %s DB...\"; sleep 2; done" $host "5432" $user $c.name))
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
      {{- $mergedCronjob := $cj.initContainers | default list }}
      {{- if $.Values.addons.redis.enabled }}
        {{- $host := include "commons.getValue" (dict "Values" $.Values "Chart" $.Chart "Release" $.Release "value" "__addons__redis__host") }}
        {{- $mergedCronjob = append $mergedCronjob (dict "name" "wait-for-redis" "image" (dict "repository" $.Values.addons.redis.image.repository "tag" ($.Values.addons.redis.image.tag | default "latest")) "command" (list "sh" "-c" (printf "until redis-cli -h %s ping | grep PONG; do echo waiting for redis; sleep 2; done" $host))) }}
      {{- end }}
      {{- if $.Values.addons.postgres.enabled }}
        {{- $mergedCronjob = append $mergedCronjob (dict "name" "wait-for-postgres" "image" (dict "repository" $.Values.addons.postgres.image.repository "tag" ($.Values.addons.postgres.image.tag | default "latest")) "command" (list "sh" "-c" (printf "until pg_isready -h %s -p %s -U %s; do echo \"Waiting for Postgres...\"; sleep 2; done" (include "postgres.host" $) "5432" (include "postgres.username" $)))) }}
      {{- end }}
      {{- $_ := set $cj "initContainers" $mergedCronjob }}
    {{- end }}
  {{- end }}
  {{- $result = append $result $c }}
{{- end }}

{{- $addons := list }}

{{- if .Values.addons.vscode.enabled }}
  {{- $volumeMounts := list (dict "name" "vscode-config" "mountPath" "/config") }}
  {{- range .Values.addons.vscode.volumes }}
    {{- $volumeMounts = append $volumeMounts (dict "name" .name "mountPath" (print "/config/workspace/" .name)) }}
  {{- end }}

  {{- $volumes := list (dict "name" "vscode-config" "pvc" (dict "name" "vscode-config" "storage" (dict "size" "1Gi" "storageClassName" (default .Values.global.pvc.storage.storageClassName .Values.addons.vscode.storageClassName)))) }}
  {{- range .Values.addons.vscode.volumes }}
    {{- $vol := dict "name" .name }}
    {{- with .pvc }}
      {{- $storage := dict "size" (default $.Values.global.pvc.storage.size .storage.size) "storageClassName" (default $.Values.global.pvc.storage.storageClassName $.Values.addons.vscode.storageClassName) }}
      {{- $vol = merge $vol (dict "pvc" (dict "name" .name "useExisting" (default true .useExisting) "storage" $storage)) }}
    {{- end }}
    {{- $volumes = append $volumes $vol }}
  {{- end }}

  {{- $vscodeSC := .Values.addons.vscode.securityContext | default dict }}
  {{- $defaults := dict
      "name" "code-server"
      "deployment" (dict
        "containers" (list (dict
            "image" (dict "repository" .Values.addons.vscode.image.repository "tag" (default "latest" .Values.addons.vscode.image.tag))
            "securityContext" (dict "runAsUser" (default 1000 $vscodeSC.runAsUser) "runAsGroup" (default 1000 $vscodeSC.runAsGroup) "fsGroup" (default 1000 $vscodeSC.fsGroup))
            "env" (list (dict "name" "DEFAULT_WORKSPACE" "value" "/config/workspace") (dict "name" "PUID" "value" (default "1000" (print (default 1000 $vscodeSC.runAsUser)))) (dict "name" "PGID" "value" (default "1000" (print (default 1000 $vscodeSC.runAsGroup)))))
            "volumeMounts" $volumeMounts
        ))
        "volumes" $volumes
      )
      "service" (dict "type" (default "ClusterIP" .Values.addons.vscode.service.type) "ports" (list (dict "name" "http" "port" .Values.addons.vscode.service.port)))
  }}

  {{- if (default dict .Values.addons.vscode.ingress).enabled }}
    {{- $_ := set $defaults "ingress" (merge (omit .Values.addons.vscode.ingress "enabled") (dict "enabled" true)) }}
  {{- end }}
  {{- $addons = append $addons (merge $defaults (omit .Values.addons.vscode "enabled")) }}
{{- end }}

{{- if .Values.addons.redis.enabled }}
  {{- $defaults := dict
    "name" "redis"
    "deployment" (dict
      "containers" (list (dict
        "image" (dict "repository" .Values.addons.redis.image.repository "tag" (.Values.addons.redis.image.tag | default "latest"))
        "livenessProbe" (dict "tcpSocket" (dict "port" .Values.addons.redis.port) "initialDelaySeconds" 5 "periodSeconds" 10)
        "readinessProbe" (dict "tcpSocket" (dict "port" .Values.addons.redis.port) "initialDelaySeconds" 5 "periodSeconds" 10)
        "volumeMounts" (list (dict "mountPath" (default "/data" .Values.addons.redis.storage.mountPath) "name" "data"))
      ))
      "volumes" (list (dict "name" "data" "pvc" (dict "name" "data" "storage" (dict "size" (default .Values.global.pvc.storage.size .Values.addons.redis.storage.size) "storageClassName" (default .Values.global.pvc.storage.storageClassName .Values.addons.redis.storage.storageClassName)))))
    )
    "service" (dict "enabled" true "type" "ClusterIP" "ports" (list (dict "name" "redis" "port" .Values.addons.redis.port)))
  }}
  {{- $addons = append $addons (merge $defaults (omit .Values.addons.redis "enabled" "name")) }}
{{- end }}

{{- if .Values.addons.pgadmin.enabled }}
  {{- $defaults := dict
    "name" "pgadmin"
    "deployment" (dict
      "containers" (list (dict
          "image" (dict "repository" .Values.addons.pgadmin.image.repository "tag" (default "latest" .Values.addons.pgadmin.image.tag))
          "env" (list (dict "name" "PGPASS_FILE" "value" "/pgadmin4/pgpass") (dict "name" "PGADMIN_DEFAULT_EMAIL" "value" .Values.addons.pgadmin.auth.email) (dict "name" "PGADMIN_DEFAULT_PASSWORD" "value" .Values.addons.pgadmin.auth.password))
          "securityContext" (dict "runAsUser" 5050 "runAsGroup" 5050 "fsGroup" 5050 "runAsNonRoot" true "readOnlyRootFilesystem" false)
          "livenessProbe" (dict "tcpSocket" (dict "port" .Values.addons.pgadmin.service.port) "initialDelaySeconds" 5 "periodSeconds" 10)
          "readinessProbe" (dict "tcpSocket" (dict "port" .Values.addons.pgadmin.service.port) "initialDelaySeconds" 5 "periodSeconds" 10)
          "volumeMounts" (list (dict "mountPath" "/pgadmin4/servers.json" "subPath" "servers.json" "name" "config") (dict "mountPath" "/pgadmin4/pgpass" "subPath" "pgpass" "name" "config"))
      ))
      "volumes" (list (dict "name" "config" "configMap" (dict "name" "pg-config" "data" (dict "servers.json" (trim (include "pgadmin.servers" $)) "pgpass" (trim (include "pgadmin.pgpass" $))))))
    )
    "service" (dict "enabled" true "type" .Values.addons.pgadmin.service.type "ports" (list (dict "name" "pgadmin" "port" .Values.addons.pgadmin.service.port)))
    "ingress" .Values.addons.pgadmin.ingress
  }}
  {{- $addons = append $addons (merge $defaults (omit .Values.addons.pgadmin "enabled" "name")) }}
{{- end }}

{{- concat $result $addons | toYaml }}
{{- end }}