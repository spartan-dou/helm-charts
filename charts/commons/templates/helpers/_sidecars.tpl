{{- define "commons.sidecars" }}
{{- range .component.sidecars }}
- name: {{ .name }}
  image:
    repository: {{ .repository }}
    tag: {{ .tag | default "latest" }}
  {{- if .ports }}
  ports:
    {{- range .ports }}
    - containerPort: {{ .containerPort }}
    {{- end }}
  {{- end }}
  {{- if .env }}
  env:
    {{- range .env }}
    - name: {{ .name }}
      value: {{ .value | quote }}
    {{- end }}
  {{- end }}
  {{- if .resources }}
  resources:
    {{- toYaml .resources | nindent 4 }}
  {{- end }}
  {{- if .volumeMounts }}
  volumeMounts:
    {{- toYaml .volumeMounts | nindent 4 }}
  {{- end }}
{{- end }}
{{- end }}
