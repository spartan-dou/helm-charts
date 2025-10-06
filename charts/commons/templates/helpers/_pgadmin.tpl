{{- define "pgadmin.servers" }}
{
  "Servers": {
  {{- $components := .Values.components }}
  {{- $raw := .Values.addons | default dict }}
  {{- $components = append $components $raw }}
  {{- $last := sub (len $components) 1 }}
  {{- range $i, $c := $components }}
    {{- $component := $c }}
    {{- with $component.postgres }}
    {{- if .enabled }}
    "{{ $i }}": {
      "Name": "{{ $component.name | default "postgres" }}",
      "Group": "{{ $.Release.Name }}",
      "Port": 5432,
      "Username": "{{ include "commons.getValue" (dict "Values" $.Values "Chart" $.Chart "Release" $.Release "component" $component "value" "__components__postgres__username") }}",
      "Host": "{{ include "commons.getValue" (dict "Values" $.Values "Chart" $.Chart "Release" $.Release "component" $component "value" "__components__postgres__host") }}",
      "MaintenanceDB": "postgres"
    }{{ if ne $i $last }},{{ end }}
    {{- end }}
    {{- end }}
  {{- end }}
  }
}
{{- end }}