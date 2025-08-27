{{- define "commons.withAddons" }}
{{- $base := .Values.components | default list }}
{{- $addons := list }}


{{/* === Fusion finale === */}}
{{- $all := concat $base $addons }}
{{- toYaml $all }}
{{- end }}
