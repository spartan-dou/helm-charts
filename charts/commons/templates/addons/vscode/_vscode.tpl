{{- define "commons.addon.vscode" }}
{{- if .Values.addons.vscode.enabled }}
  {{- $defaults := dict
    "name" "vscode"
    "deployment" (dict
      "name" "code-server"
      "image" "codercom/code-server"
      "tag" "latest"
      "ports" (list (dict "name" "http" "containerPort" 8080))
      "volumeMounts" (list (dict "name" "vscode-data" "mountPath" "/home/coder/project"))
      "volumes" (list (dict "name" "vscode-data" "emptyDir" (dict)))
    )
    "service" (dict
      "enabled" true
      "type" "ClusterIP"
      "ports" (list (dict "name" "http" "port" 8080))
    )
  }}
  {{- $raw := .Values.addons.vscode | default dict }}
  {{- $overrides := omit $raw "enable" }}
  {{- $vscode := merge $defaults $overrides }}
  {{- return $vscode }}
{{- end }}
{{- end }}
