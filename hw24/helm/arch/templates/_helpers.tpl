{{- define "arch.labels" -}}
helm.sh/chart: {{ include "arch.name" $ }}-{{ $.Chart.Version | replace "+" "_" }}
{{ include "arch.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{- define "arch.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "arch.selectorLabels" -}}
app.kubernetes.io/name: {{ include "arch.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}
