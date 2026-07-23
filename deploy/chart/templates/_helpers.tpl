{{- define "production-simulation.name" -}}
production-simulation
{{- end }}

{{- define "production-simulation.labels" -}}
app.kubernetes.io/name: {{ include "production-simulation.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{- define "production-simulation.selectorLabels" -}}
app.kubernetes.io/name: {{ include "production-simulation.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}
