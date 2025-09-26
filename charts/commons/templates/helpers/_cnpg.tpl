{{- define "commons.waitForPostgres" -}}
{{- $component := .component | default "" }}
{{- with $component.postgres }}
name: wait-for-postgres-{{ $component.name }}
image: {{ .image | default $.Values.addons.postgres.image.repository }}:{{ .tag | default $.Values.addons.postgres.image.tag }}
command:
  - sh
  - -c
  - |-
    until pg_isready -h {{ .host | default "postgres" }} -p {{ .port | default "5432" }}; do
      echo "Waiting for Postgres to be ready...";
      sleep 2;
    done
resources:
  requests:
    cpu: 10m
    memory: 16Mi
  limits:
    cpu: 50m
    memory: 32Mi
{{- end }}
{{- end }}