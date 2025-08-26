{{- define "commons.withAddons" }}
{{- $base := .Values.components | default list }}
{{- $addons := list }}

{{- $vscode := include "commons.addon.vscode" . | fromYamlArray }}
{{- if $vscode }}
  {{- $addons = append $addons $vscode }}
{{- end }}

{{- $redis := include "commons.addon.redis" . | fromYamlArray }}
{{- $names := pluck "name" $addons }}
{{- if and $redis (not (has "redis" $names)) }}
  {{- $addons = append $addons $redis }}
{{- end }}

{{- $all := concat $base $addons }}
{{- toYaml .Values.components }}
{{- end }}
