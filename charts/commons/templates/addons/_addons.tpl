{{- define "commons.withAddons" }}
{{- $base := .Values.components | default list }}
{{- $addons := list }}


{{- toYaml .Values.components }}
{{- end }}
