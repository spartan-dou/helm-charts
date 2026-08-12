{{/*
  initContainer commun "wait-for-redis", injecté dans les deployments et
  cronjobs quand addons.redis.enabled. Prend le contexte racine ($) en entrée.
*/}}
{{- define "commons.waitForRedisInitContainer" -}}
{{- $host := include "commons.getValue" (dict "Values" .Values "Chart" .Chart "Release" .Release "value" "__addons__redis__host") -}}
{{- $redisAuth := or (ne (default "" .Values.addons.redis.password) "") (ne (default "" .Values.addons.redis.passwordSecretRef) "") -}}
{{- $redisKey := include "commons.getValue" (dict "Values" .Values "Chart" .Chart "Release" .Release "value" "__addons__redis__password_secret_key") -}}
{{- $redisInit := dict
  "name" "wait-for-redis"
  "image" (dict
    "repository" .Values.addons.redis.image.repository
    "tag" .Values.addons.redis.image.tag
  )
  "env" (ternary (list (dict "name" "REDIS_PASSWORD" "valueFrom" (dict "secretKeyRef" (dict "name" "__addons__redis__password_secret" "key" $redisKey)))) (list) $redisAuth)
  "command" (list "sh" "-c" (printf "until redis-cli -h %s %s ping | grep PONG; do echo waiting for redis; sleep 2; done" $host (ternary "-a \"$REDIS_PASSWORD\"" "" $redisAuth)))
-}}
{{- toYaml $redisInit -}}
{{- end -}}

{{/*
  initContainer commun "wait-for-postgres", pour le cluster CloudNativePG
  partagé (addons.postgres), injecté dans les deployments et cronjobs quand
  addons.postgres.enabled. Prend le contexte racine ($) en entrée.
*/}}
{{- define "commons.waitForSharedPostgresInitContainer" -}}
{{- $postgresInit := dict
  "name" "wait-for-postgres"
  "image" (include "commons.postgres.image" (dict "Values" .Values "postgres" .Values.addons.postgres) | fromYaml)
  "command" (list "sh" "-c" (printf "until pg_isready -h %s -p %s -U %s; do echo \"Waiting for Postgres to be ready...\"; sleep 2; done" (include "commons.postgres.host" .) "5432" (include "commons.postgres.username" .)))
  "resources" (dict
    "requests" (dict "cpu" "10m" "memory" "16Mi")
    "limits"   (dict "cpu" "50m" "memory" "32Mi")
  )
-}}
{{- toYaml $postgresInit -}}
{{- end -}}

{{/*
  Liste unique de "components" consommée par tous les templates de ressources.
  Elle contient :

    1. les `components` des values ayant un `deployment`, enrichis des
       initContainers d'attente (redis, postgres partagé, postgres embarqué)
       sur le deployment comme sur chaque cronjob ;
    2. les addons activés (`vscode`, `redis`, `pgadmin`), normalisés au même
       format qu'un component — d'où le fait qu'ils produisent Deployment,
       Service, Ingress… via exactement les mêmes templates.

  Pour chaque addon, les valeurs de `addons.<nom>` sont fusionnées par-dessus
  un squelette de défauts, à l'exception des clés de pilotage (`enabled`,
  `name`, `password`…) qui sont retirées avant fusion.

  Entrée : le contexte racine ($). Sortie : YAML, à relire avec `fromYamlArray`.
*/}}
{{- define "commons.withAddons" }}
{{- $rawComponents := .Values.components | default list -}}
{{- $base := list -}}
{{- range $rawComponents -}}
  {{- if .deployment -}}
    {{- $base = append $base (deepCopy .) -}}
  {{- end -}}
{{- end -}}

{{- $result := list }}
{{- range $i, $c := $base }}
  {{- $existing := $c.deployment.initContainers | default list }}
  {{- $merged := list }}
  {{- range $existing }}
    {{- $merged = append $merged . }}
  {{- end }}

  {{- if $.Values.addons.redis.enabled }}
    {{- $merged = append $merged (include "commons.waitForRedisInitContainer" $ | fromYaml) }}
  {{- end }}

  {{- if $.Values.addons.postgres.enabled }}
    {{- $merged = append $merged (include "commons.waitForSharedPostgresInitContainer" $ | fromYaml) }}
  {{- end }}

  {{- if and $c.postgres $c.postgres.enabled }}
    {{- $host := include "commons.getValue" (dict "Values" $.Values "Chart" $.Chart "Release" $.Release "component" $c "value" "__components__postgres__host") }}
    {{- $user := include "commons.getValue" (dict "Values" $.Values "Chart" $.Chart "Release" $.Release "component" $c "value" "__components__postgres__username") }}
    {{- $postgresInit := dict
      "name" (printf "wait-for-postgres-%s" $c.name)
      "image" (include "commons.postgres.image" (dict "Values" $.Values "postgres" $c.postgres) | fromYaml)
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
        {{- $mergedCronjob = append $mergedCronjob (include "commons.waitForRedisInitContainer" $ | fromYaml) }}
      {{- end }}

      {{- if $.Values.addons.postgres.enabled }}
        {{- $mergedCronjob = append $mergedCronjob (include "commons.waitForSharedPostgresInitContainer" $ | fromYaml) }}
      {{- end }}

      {{- $_ := set $cj "initContainers" $mergedCronjob }}
    {{- end }}
  {{- end }}

  {{- $result = append $result $c }}
{{- end }}

{{- $addons := list }}

{{/* === Addon `addons.vscode` === */}}
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

  {{- $vscodeSC := .Values.addons.vscode.securityContext | default dict }}
  {{- $defaults := dict
        "name" "code-server"
        "deployment" (dict
          "securityContext" (dict
            "fsGroup" (default 1000 (get $vscodeSC "fsGroup"))
          )
          "containers" (list (dict
              "image" (dict
                  "repository" .Values.addons.vscode.image.repository
                  "tag" (default "latest" .Values.addons.vscode.image.tag)
              )
              "securityContext" (dict
                "runAsUser" (default 0 (get $vscodeSC "runAsUser"))
                "runAsGroup" (default 1000 (get $vscodeSC "runAsGroup"))
              )
              "env" (list
                      (dict "name" "DEFAULT_WORKSPACE" "value" "/config/workspace")
                      (dict "name" "PUID" "value" (default "0" (get $vscodeSC "runAsUser")))
                      (dict "name" "PGID" "value" (default "1000" (get $vscodeSC "runAsGroup")))
                    )
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
    {{- $ingressDefaults := dict "enabled" true }}
    {{- /* `enabled` est retiré des overrides pour ne pas écraser la condition */ -}}
    {{- $ingressOverrides := omit (default dict .Values.addons.vscode.ingress) "enabled" }}
    {{- $_ := set $defaults "ingress" (merge $ingressDefaults $ingressOverrides) }}
  {{- end }}
  {{- $raw := .Values.addons.vscode | default dict }}
  {{- $overrides := omit $raw "enabled" }}
  {{- $vscode := merge $defaults $overrides }}
  {{- $addons = append $addons $vscode }}
{{- end }}

{{/* === Addon `addons.redis` === */}}
{{- if .Values.addons.redis.enabled }}
  {{- $redisAuth := or (ne (default "" .Values.addons.redis.password) "") (ne (default "" .Values.addons.redis.passwordSecretRef) "") }}
  {{- $redisOwnSecret := and $redisAuth (not .Values.addons.redis.passwordSecretRef) }}
  {{- $redisKey := include "commons.getValue" (dict "Values" .Values "Chart" .Chart "Release" .Release "value" "__addons__redis__password_secret_key") }}
  {{- $defaults := dict
    "name" "redis"
    "secrets" (ternary (list (dict "name" "auth" "data" (dict "password" .Values.addons.redis.password))) (list) $redisOwnSecret)
    "deployment" (dict
      "containers" (list (dict
        "image" (dict
            "repository" .Values.addons.redis.image.repository
            "tag" (default "latest" .Values.addons.redis.image.tag)
        )
        "args" (ternary (list "--requirepass" "$(REDIS_PASSWORD)") (list) $redisAuth)
        "env" (ternary (list (dict "name" "REDIS_PASSWORD" "valueFrom" (dict "secretKeyRef" (dict "name" "__addons__redis__password_secret" "key" $redisKey)))) (list) $redisAuth)
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
        "name" "data"
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
  {{- $overrides := omit $raw "enabled" "name" "password" "passwordSecretRef" }}
  {{- $redis := merge $defaults $overrides }}
  {{- $addons = append $addons $redis }}
{{- end }}

{{/* === Addon `addons.pgadmin` === */}}
{{- if .Values.addons.pgadmin.enabled }}
  {{- $defaults := dict
    "name" "pgadmin"
    "deployment" (dict
      "securityContext" (dict
        "fsGroup" 5050
      )
      "initContainers" (list (dict
        "name" "render-pgpass"
        "image" (dict
          "repository" .Values.addons.pgadmin.image.repository
          "tag" (default "latest" .Values.addons.pgadmin.image.tag)
        )
        "securityContext" (dict
          "runAsUser" 5050
          "runAsGroup" 5050
          "runAsNonRoot" true
        )
        "command" (list "sh" "-c" (trim (include "commons.pgadmin.pgpassScript" (dict "Values" $.Values "Chart" $.Chart "Release" $.Release))))
        "env" (include "commons.pgadmin.pgpassEnv" (dict "Values" $.Values "Chart" $.Chart "Release" $.Release) | fromYamlArray)
        "volumeMounts" (list (dict "mountPath" "/pgpass" "name" "pgpass"))
      ))
      "containers" (list (dict
          "image" (dict
              "repository" .Values.addons.pgadmin.image.repository
              "tag" (default "latest" .Values.addons.pgadmin.image.tag)
          )
        "env" (concat
          (list
            (dict "name" "PGPASS_FILE" "value" "/pgadmin4/pgpass")
            (dict "name" "PGADMIN_DEFAULT_EMAIL" "value" .Values.addons.pgadmin.auth.email)
          )
          (ternary
            (list (dict "name" "PGADMIN_DEFAULT_PASSWORD" "secretRef" .Values.addons.pgadmin.auth.passwordSecretRef))
            (list (dict "name" "PGADMIN_DEFAULT_PASSWORD" "value" .Values.addons.pgadmin.auth.password))
            (ne (default "" .Values.addons.pgadmin.auth.passwordSecretRef) "")
          )
        )
        "securityContext" (dict
          "runAsUser" 5050
          "runAsGroup" 5050
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
        (dict "mountPath" "/pgadmin4/pgpass" "subPath" "pgpass" "name" "pgpass")
      )
      ))
    "volumes" (list
        (dict
          "name" "config"
          "configMap" (dict
            "name" "pg-config"
            "data" (dict
              "servers.json" (trim (include "commons.pgadmin.servers" (dict "Values" $.Values "Chart" $.Chart "Release" $.Release)))
            ))
        )
        (dict "name" "pgpass" "emptyDir" (dict))
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

{{/* === Components + addons === */}}
{{- $all := concat $result $addons }}
{{- toYaml $all }}
{{- end }}
