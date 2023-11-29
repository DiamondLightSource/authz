{{/*
Expand the name of the chart.
*/}}
{{- define "opal.name" -}}
{{- printf "%s-opal-client" .Chart.Name | default .Values.opal.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "opal.fullname" -}}
{{- if .Values.opal.fullnameOverride }}
{{- .Values.opal.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := printf "%s-opal-client" .Chart.Name | default .Values.opal.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "opal.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "opal.labels" -}}
helm.sh/chart: {{ include "opal.chart" . }}
{{ include "opal.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "opal.selectorLabels" -}}
app.kubernetes.io/name: {{ include "opal.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "opal.serviceAccountName" -}}
{{- if .Values.opal.serviceAccount.create }}
{{- default (include "opal.fullname" .) .Values.opal.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.opal.serviceAccount.name }}
{{- end }}
{{- end }}
