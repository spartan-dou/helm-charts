{{- define "commons.withAddons" }}
{{- $base := .Values.components | default list }}
{{- $addons := list }}

{{- $vscode := include "commons.addon.vscode" . | fromYamlArray }}
{{- if $vscode }}
  {{- $addons = append $addons $vscode }}
{{- end }}


{{- $all := concat $base $addons }}
{{- toYaml .Values.components }}
{{- end }}
