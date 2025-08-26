{{- define "commons.withAddons" }}
{{- $base := .Values.components | default list }}
{{- $addons := list }}

{{- $vscode := include "commons.addon.vscode" . | fromYamlArray }}
{{- if and .Values.addons.vscode.enabled $vscode }}
  {{- $addons = append $addons $vscode }}
{{- end }}


{{- $all := concat $base $addons }}
{{- toYaml $all }}
{{- end }}
