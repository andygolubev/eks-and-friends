{{- define "auth.fullname" -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "auth.labels" -}}
app.kubernetes.io/name: auth
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{- define "auth.selectorLabels" -}}
app.kubernetes.io/name: auth
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}
