{{/*
  Bloc `env:` d'un conteneur : `TZ` (depuis `global.timezone`) suivi des
  variables déclarées sur le conteneur. Chaque entrée accepte, au choix :

    value      -> résolu par `commons.getValue` (placeholders `__…__`)
    secretRef  -> alias de la section racine `secrets`, rendu en `secretKeyRef`
    valueFrom  -> forme Kubernetes brute ; le `secretKeyRef.name` passe lui
                  aussi par `commons.getValue`

  Entrée : dict "Values" $.Values "Chart" $.Chart "Release" $.Release
                "component" <component> "env" <liste des env du conteneur>
*/}}
{{- define "commons.containers.env" }}
{{- $component := .component }}
{{- $env := .env }}
{{- with $component }}
env:
  - name: TZ
    value: {{ $.Values.global.timezone | quote }}
  {{- range $env }}
  - name: {{ .name }}
    {{- with .value }}
    value: {{ include "commons.getValue" (dict "Values" $.Values "Chart" $.Chart "Release" $.Release "component" $component "value" .) | quote }}
    {{- end }}
    {{- with .secretRef }}
    valueFrom:
      secretKeyRef:
        name: {{ include "commons.secretRefName" (dict "Values" $.Values "alias" .) }}
        key: {{ include "commons.secretRefKey" (dict "Values" $.Values "alias" .) }}
    {{- end }}
    {{- with .valueFrom }}
    valueFrom:
      {{- if .secretKeyRef }}
      secretKeyRef:
        name: {{ include "commons.getValue" (dict "Values" $.Values "Chart" $.Chart "Release" $.Release "component" $component "value" .secretKeyRef.name) }}
        key: {{ .secretKeyRef.key }}
      {{- else }}
      {{- toYaml . | nindent 6 }}
      {{- end }}
    {{- end }}
  {{- end }}
{{- end }}
{{- end }}

{{/*
  Une sonde. Le handler est le premier renseigné parmi `tcpSocket`, `exec` et
  `httpGet` ; les temporisations non précisées viennent des défauts du rôle.
  Ne rend rien si la sonde n'est pas configurée.

  Entrée : dict "name" <livenessProbe|readinessProbe|startupProbe>
                "probe" <config|nil>
                "defaults" (dict "initialDelaySeconds" … "periodSeconds" …
                                 "timeoutSeconds" … "failureThreshold" …)
*/}}
{{- define "commons.containers.probe" -}}
{{- $defaults := .defaults }}
{{- with .probe }}
{{ $.name }}:
  {{- if .tcpSocket }}
  tcpSocket:
    {{- toYaml .tcpSocket | nindent 4 }}
  {{- else if .exec }}
  exec:
    {{- toYaml .exec | nindent 4 }}
  {{- else if .httpGet }}
  httpGet:
    path: {{ default "/" .httpGet.path }}
    port: {{ default "http" .httpGet.port }}
  {{- end }}
  initialDelaySeconds: {{ default $defaults.initialDelaySeconds .initialDelaySeconds }}
  periodSeconds: {{ default $defaults.periodSeconds .periodSeconds }}
  timeoutSeconds: {{ default $defaults.timeoutSeconds .timeoutSeconds }}
  failureThreshold: {{ default $defaults.failureThreshold .failureThreshold }}
{{- end }}
{{- end }}

{{/*
  Les trois sondes d'un conteneur. `probe` sert de configuration commune :
  elle est reprise pour chaque sonde non définie individuellement. Les défauts
  de temporisation diffèrent par rôle — le démarrage est le plus permissif, la
  readiness la plus réactive.

  Entrée : le conteneur (`.livenessProbe`, `.readinessProbe`, `.startupProbe`,
           `.probe`).
*/}}
{{- define "commons.containers.probes" -}}
{{- include "commons.containers.probe" (dict "name" "livenessProbe" "probe" (or .livenessProbe .probe) "defaults" (dict "initialDelaySeconds" 10 "periodSeconds" 10 "timeoutSeconds" 2 "failureThreshold" 3)) }}
{{- include "commons.containers.probe" (dict "name" "readinessProbe" "probe" (or .readinessProbe .probe) "defaults" (dict "initialDelaySeconds" 5 "periodSeconds" 5 "timeoutSeconds" 2 "failureThreshold" 3)) }}
{{- include "commons.containers.probe" (dict "name" "startupProbe" "probe" (or .startupProbe .probe) "defaults" (dict "initialDelaySeconds" 0 "periodSeconds" 5 "timeoutSeconds" 2 "failureThreshold" 30)) }}
{{- end -}}

{{/*
  `securityContext` de pod : `global.securityContext` fusionné (mergeOverwrite)
  avec celui du deployment/cronjob, qui a le dernier mot. Ne rend rien si les
  deux sont vides.

  Entrée : dict "global" $.Values.global "securityContext" <securityContext|nil>
*/}}
{{- define "commons.pod.securityContext" -}}
{{- $sc := .securityContext | default dict -}}
{{- $gsc := dict -}}
{{- if .global -}}
  {{- $gsc = .global.securityContext | default dict -}}
{{- end -}}
{{- $merged := mergeOverwrite (deepCopy $gsc) (deepCopy $sc) -}}
{{- if $merged -}}
securityContext:
  {{- toYaml $merged | nindent 2 }}
{{- end -}}
{{- end -}}
