{{- define "pgadmin.servers" }}
{
  "Servers": {
  {{- $workList := .Values.components | default list }}
  {{- if .Values.addons }}
    {{- $workList = append $workList .Values.addons }}
  {{- end }}
  {{- $pgComponents := list }}
  {{- range $workList }}
    {{- if and .postgres .postgres.enabled }}
      {{- $pgComponents = append $pgComponents . }}
    {{- end }}
  {{- end }}
  {{- $last := sub (len $pgComponents) 1 }}
  {{- range $i, $component := $pgComponents }}
    "{{ $i }}": {
      "Name": "{{ $component.name | default "postgres" }}",
      "Group": "{{ $.Release.Name }}",
      "Port": 5432,
      "Username": "{{ include "commons.getValue" (dict "Values" $.Values "Chart" $.Chart "Release" $.Release "component" $component "value" "__components__postgres__username") }}",
      "Host": "{{ include "commons.getValue" (dict "Values" $.Values "Chart" $.Chart "Release" $.Release "component" $component "value" "__components__postgres__host") }}",
      "MaintenanceDB": "postgres",
      "PassFile": "/pgadmin4/pgpass"
    }{{ if ne $i $last }},{{ end }}
  {{- end }}
  }
}
{{- end }}

{{/* ========================================================== */}}

{{/*
  Le fichier `pgpass` contient des mots de passe : il n'est donc jamais rendu
  dans un ConfigMap. Il est écrit au démarrage du pod par un initContainer, à
  partir de variables d'environnement injectées depuis les Secrets Postgres
  (`secretKeyRef`), dans un volume `emptyDir` partagé.

  `pgadmin.pgpassEnv` produit la liste des env (une par cluster Postgres),
  `pgadmin.pgpassScript` le script qui reconstitue le fichier.
*/}}
{{- define "pgadmin.pgpassEnv" }}
  {{- $workList := .Values.components | default list }}
  {{- if .Values.addons }}
    {{- $workList = append $workList .Values.addons }}
  {{- end }}
  {{- $envs := list }}
  {{- $i := 0 }}
  {{- range $component := $workList }}
    {{- if and $component.postgres $component.postgres.enabled }}
      {{- $secret := include "commons.getValue" (dict "Values" $.Values "Chart" $.Chart "Release" $.Release "component" $component "value" "__components__postgres__password_secret") }}
      {{- $key := include "commons.getValue" (dict "Values" $.Values "Chart" $.Chart "Release" $.Release "component" $component "value" "__components__postgres__password_secret_key") }}
      {{- $envs = append $envs (dict
        "name" (printf "PGPASS_PWD_%d" $i)
        "valueFrom" (dict "secretKeyRef" (dict "name" $secret "key" $key))
      ) }}
      {{- $i = add1 $i }}
    {{- end }}
  {{- end }}
  {{- toYaml $envs }}
{{- end }}

{{- define "pgadmin.pgpassScript" }}
  {{- $workList := .Values.components | default list }}
  {{- if .Values.addons }}
    {{- $workList = append $workList .Values.addons }}
  {{- end }}
  {{- $lines := list "umask 077" ": > /pgpass/pgpass" }}
  {{- $i := 0 }}
  {{- range $component := $workList }}
    {{- if and $component.postgres $component.postgres.enabled }}
      {{- $host := include "commons.getValue" (dict "Values" $.Values "Chart" $.Chart "Release" $.Release "component" $component "value" "__components__postgres__host") }}
      {{- $user := include "commons.getValue" (dict "Values" $.Values "Chart" $.Chart "Release" $.Release "component" $component "value" "__components__postgres__username") }}
      {{- $lines = append $lines (printf "printf '%%s:5432:postgres:%%s:%%s\\n' '%s' '%s' \"$PGPASS_PWD_%d\" >> /pgpass/pgpass" $host $user $i) }}
      {{- $i = add1 $i }}
    {{- end }}
  {{- end }}
  {{- join "\n" $lines }}
{{- end }}