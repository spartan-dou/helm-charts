{{- range .Values.components }}
{{- $component := . }}
{{- with $component.deployment }}
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ include "commons.fullname" . }}-{{ $component.name }}
  labels:
    {{- include "commons.labels" . | nindent 4 }}
spec:
  replicas: {{ default 1 .replicas }}
  selector:
    matchLabels:
      app: {{ $component.name }}
  template:
    metadata:
      labels:
        app: {{ $component.name }}
    spec:
      containers:
        - name: {{ $component.name }}
          image: {{ .image }}:{{ .tag }}
          env:
            - name: TZ
              value: {{ $.Values.timezone }}
            {{- range .env }}
            - name: {{ .name }}
              value: {{ .value | quote }}
            {{- end }}
          volumeMounts:
            {{- range .volumeMounts }}
            - name: {{ .name }}
              mountPath: {{ .mountPath }}
            {{- end }}
          ports:
            {{- range .ports }}
            - name: {{ .name }}
              containerPort: {{ .containerPort }}
              protocol: {{ default "tcp" .containerPort }}
              {{- with .hostPort }}
              hostPort: {{ . }}
              {{- end }}
            {{- end }}
      volumes:
        {{- if .volumes }}
        {{- toYaml .volumes | nindent 8 }}
        {{- end }}
{{- end }}
---
{{- end }}
