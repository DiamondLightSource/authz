{{/*
Expand the name of the chart.
*/}}
{{- define "opa.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "opa.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
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
{{- define "opa.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "opa.labels" -}}
helm.sh/chart: {{ include "opa.chart" . }}
{{ include "opa.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "opa.selectorLabels" -}}
app.kubernetes.io/name: {{ include "opa.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "opa.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "opa.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

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
