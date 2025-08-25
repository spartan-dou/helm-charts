{{- define "commons.withAddons" }}
{{- $base := .Values.components | default list }}
{{- $addons := list }}

{{- $vscode := include "commons.addon.vscode" . | fromYaml }}
{{- if $vscode }}
  {{- $addons = append $addons $vscode }}
{{- end }}

{{- $redis := include "commons.addon.redis" . | fromYaml }}
{{- $names := pluck "name" $addons }}
{{- if and $redis (not (has "redis" $names)) }}
  {{- $addons = append $addons $redis }}
{{- end }}

{{- $all := concat $base $addons }}
{{- toYaml $all }}
{{- (printf "DEBUG: addons = %#v" toYaml $all | fromYamlArray) }}
{{- (printf "DEBUG: addons = %#v" "base") }}
{{- (printf "DEBUG: addons = %#v" toYaml $base | fromYamlArray) }}
{{- end }}
