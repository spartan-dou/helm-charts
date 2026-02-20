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

{{- define "pgadmin.pgpass" }}
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
  {{- range $component := $pgComponents }}
    {{- $host := include "commons.getValue" (dict "Values" $.Values "Chart" $.Chart "Release" $.Release "component" $component "value" "__components__postgres__host") -}}
    {{- $user := include "commons.getValue" (dict "Values" $.Values "Chart" $.Chart "Release" $.Release "component" $component "value" "__components__postgres__username") -}}
    {{- $pass := include "commons.getValue" (dict "Values" $.Values "Chart" $.Chart "Release" $.Release "component" $component "value" "__components__postgres__password") -}}
{{ $host }}:5432:postgres:{{ $user }}:{{ $pass }}
  {{- end }}
{{- end }}