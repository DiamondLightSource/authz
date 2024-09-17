{{/*
Create the tag to be used to pull the chart
*/}}
{{- define "opa.imageTag" -}}
{{- if .Values.image.tagOverride }}
{{- .Values.image.tagOverride }}
{{- else }}
{{- $version := default .Chart.AppVersion .Values.image.version }}
{{- if .Values.image.envoy }}
{{- print $version "-envoy" }}
{{- else }}
{{- $version }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Determine the query port to be used
*/}}
{{- define "opa.queryPort" -}}
{{- if .Values.portOverride }}
{{- .Values.image.portOverride }}
{{- else }}
{{- if .Values.image.envoy }}
{{- 9191 }}
{{- else }}
{{- 8181 }}
{{- end }}
{{- end }}
{{- end }}
