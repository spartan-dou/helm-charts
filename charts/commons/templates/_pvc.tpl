{{- range .Values.components }}
{{- $component := . }}
{{- with $component.pvc }}
{{- range . }}
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: {{ printf "%s-%s" $component.name .name }}
  labels:
    {{ include "commons.labels" (dict "Chart" $.Chart "Values" $.Values "Release" $.Release "name" $component.name) | nindent 4 }}
spec:
  accessModes: {{ toYaml .accessModes | nindent 4 }}
  resources:
    requests:
      storage: {{ .storage }}
  {{- if .storageClassName }}
  storageClassName: {{ .storageClassName }}
  {{- end }}
  {{- if .volumeMode }}
  volumeMode: {{ .volumeMode }}
  {{- end }}
  {{- if .selector }}
  selector:
    {{- toYaml .selector | nindent 4 }}
  {{- end }}
---
{{- end }}
{{- end }}
{{- end }}
