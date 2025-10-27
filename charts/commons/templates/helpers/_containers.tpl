{{- define "containers.envs" }}
env:
  - name: TZ
    value: {{ ..Values.global.timezone | quote }}
  {{- range .env }}
  - name: {{ .name }}
    {{- with .value }}
    value: {{ include "commons.getValue" (dict "Values" ..Values "Chart" ..Chart "Release" ..Release "component" .component "value" .) | quote }}
    {{- end }}
    {{- with .valueFrom }}
    valueFrom:
      {{- if .secretKeyRef }}
      secretKeyRef:
        name: {{ include "commons.getValue" (dict "Values" ..Values "Chart" ..Chart "Release" ..Release "component" .component "value" .secretKeyRef.name) }}
        key: {{ .secretKeyRef.key }}
      {{- else }}
      {{- toYaml . | nindent 16 }}
      {{- end }}
    {{- end }}
  {{- end }}
{{- end }}

{{- define "containers.probes" }}
{{- .livenessProbe := or .livenessProbe .probe }}
{{- with .livenessProbe }}
livenessProbe:
  {{- if .tcpSocket }}
  tcpSocket:
    {{- toYaml .tcpSocket | nindent 14 }}
  {{- else if .exec }}
  exec:
    {{- toYaml .exec | nindent 14 }}
  {{- else if .httpGet }}
  httpGet:
    path: {{ default "/" .httpGet.path }}
    port: {{ default "http" .httpGet.port }}
  {{- end }}
  initialDelaySeconds: {{ default 10 .initialDelaySeconds }}
  periodSeconds: {{ default 10 .periodSeconds }}
  timeoutSeconds: {{ default 2 .timeoutSeconds }}
  failureThreshold: {{ default 3 .failureThreshold }}
{{- end }}

{{- .readinessProbe := or .readinessProbe .probe }}
{{- with .readinessProbe }}
readinessProbe:
  {{- if .tcpSocket }}
  tcpSocket:
    {{- toYaml .tcpSocket | nindent 14 }}
  {{- else if .exec }}
  exec:
    {{- toYaml .exec | nindent 14 }}
  {{- else if .httpGet }}
  httpGet:
    path: {{ default "/" .httpGet.path }}
    port: {{ default "http" .httpGet.port }}
  {{- end }}
  initialDelaySeconds: {{ default 5 .initialDelaySeconds }}
  periodSeconds: {{ default 5 .periodSeconds }}
  timeoutSeconds: {{ default 2 .timeoutSeconds }}
  failureThreshold: {{ default 3 .failureThreshold }}
{{- end }}

{{- .startupProbe := or .startupProbe .probe }}
{{- with .startupProbe }}
startupProbe:
  {{- if .tcpSocket }}
  tcpSocket:
    {{- toYaml .tcpSocket | nindent 14 }}
  {{- else if .exec }}
  exec:
    {{- toYaml .exec | nindent 14 }}
  {{- else if .httpGet }}
  httpGet:
    path: {{ default "/" .httpGet.path }}
    port: {{ default "http" .httpGet.port }}
  {{- end }}
  initialDelaySeconds: {{ default 0 .initialDelaySeconds }}
  periodSeconds: {{ default 5 .periodSeconds }}
  timeoutSeconds: {{ default 2 .timeoutSeconds }}
  failureThreshold: {{ default 30 .failureThreshold }}
{{- end }}
{{- end }}

{{- define "containers.sidecars" }}
{{- range .component.sidecars }}
- name: {{ .name }}
  image: {{ .image.repository }}:{{ .image.tag | default "latest" }}
  {{- with .command }}
  command:
    {{ toYaml . | nindent 12 }}
  {{- end }}
  {{- with .args }}
  args:
    {{ toYaml . | nindent 12 }}
  {{- end }}
  {{- with .securityContext }}
  {{- if ne .enabled false }}
  securityContext:
    {{- toYaml . | nindent 12 }}
  {{- end }}
  {{- end }}
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
