{{- $components := include "commons.withAddons" . | fromYaml }}
{{- range $components }}
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
      {{- if $component.initContainers.containers }}
      initContainers:
      {{- if .Values.addons.redis.enable }}
        {{ include "commons.redisInitContainer" . | indent 2 }}
      {{- end }}
      {{- range $component.initContainers.containers }}
        - name: {{ .name }}
          image: {{ .image }}:{{ default "latest" .tag }}
          {{- if .command }}
          command:
            {{- range .command }}
            - {{ . }}
            {{- end }}
          {{- end }}
          {{- if .args }}
          args:
            {{- range .args }}
            - {{ . }}
            {{- end }}
          {{- end }}
          {{- if .env }}
          env:
            {{- range .env }}
            - name: {{ .name }}
              value: {{ .value | quote }}
            {{- end }}
          {{- end }}
          {{- if .volumeMounts }}
          volumeMounts:
            {{- range .volumeMounts }}
            - name: {{ .name }}
              mountPath: {{ .mountPath }}
            {{- end }}
          {{- end }}
      {{- end }}
      {{- end }}
      containers:
        - name: {{ .name }}
          image: {{ .image }}:{{ default "latest" .tag }}
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
      {{- if .volumes }}
      volumes:
        {{- toYaml .volumes | nindent 8 }}
      {{- end }}
---
{{- end }}
{{- end }}
