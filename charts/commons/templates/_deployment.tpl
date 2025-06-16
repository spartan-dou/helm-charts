{{- range .Values.components }}
{{- $component := . }}
{{- with $component.deployment }}
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ include "commons.fullname" (dict "Chart" $.Chart "Values" $.Values "Release" $.Release "name" $component.name) }}
  labels:
    {{ include "commons.labels" (dict "Chart" $.Chart "Values" $.Values "Release" $.Release "name" $component.name) | nindent 4 }}
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
        {{- range .containers }}
        - name: {{ .name }}
          image: "{{ .image }}:{{ default "latest" .tag }}"
          env:
            - name: TZ
              value: {{ $.Values.timezone | quote }}
            {{- range .env }}
            - name: {{ .name }}
              value: {{ .value | quote }}
            {{- end }}
          {{- if .volumeMounts }}
          volumeMounts:
            {{- range .volumeMounts }}
            - name: {{ .name }}
              mountPath: {{ .mountPath }}
            {{- end }}
          {{- end }}
          {{- if .ports }}
          ports:
            {{- range .ports }}
            - name: {{ .name }}
              containerPort: {{ .containerPort }}
              protocol: {{ default "TCP" .protocol }}
              {{- with .hostPort }}
              hostPort: {{ . }}
              {{- end }}
            {{- end }}
          {{- end }}
          {{- with .livenessProbe }}
          livenessProbe:
            {{- toYaml . | nindent 6 }}
          {{- end }}
          {{- with .readinessProbe }}
          readinessProbe:
            {{- toYaml . | nindent 6 }}
          {{- end }}
          {{- with .startupProbe }}
          startupProbe:
            {{- toYaml . | nindent 6 }}
          {{- end }}
        {{- end }}  
      {{- if .volumes }}
      volumes:
        {{- toYaml .volumes | nindent 8 }}
      {{- end }}
---
{{- end }}
{{- end }}
