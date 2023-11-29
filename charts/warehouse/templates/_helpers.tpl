{{/*
Expand the name of the chart.
*/}}
{{- define "opal-server.name" -}}
{{- printf "%s-opal-server" .Chart.Name | default .Values.opal.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "opal-server.fullname" -}}
{{- if .Values.opal.fullnameOverride }}
{{- .Values.opal.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := printf "%s-opal-server" .Chart.Name | default .Values.opal.nameOverride }}
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
{{- define "opal-server.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "opal-server.labels" -}}
helm.sh/chart: {{ include "opal-server.chart" . }}
{{ include "opal-server.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "opal-server.selectorLabels" -}}
app.kubernetes.io/name: {{ include "opal-server.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "opal-server.serviceAccountName" -}}
{{- if .Values.opal.serviceAccount.create }}
{{- default (include "opal-server.fullname" .) .Values.opal.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.opal.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Expand the name of the chart.
*/}}
{{- define "bundler.name" -}}
{{- printf "%s-bundler" .Chart.Name | default .Values.bundler.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "bundler.fullname" -}}
{{- if .Values.bundler.fullnameOverride }}
{{- .Values.bundler.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := printf "%s-bundler" .Chart.Name | default .Values.bundler.nameOverride }}
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
{{- define "bundler.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "bundler.labels" -}}
helm.sh/chart: {{ include "bundler.chart" . }}
{{ include "bundler.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "bundler.selectorLabels" -}}
app.kubernetes.io/name: {{ include "bundler.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "bundler.serviceAccountName" -}}
{{- if .Values.bundler.serviceAccount.create }}
{{- default (include "bundler.fullname" .) .Values.bundler.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.bundler.serviceAccount.name }}
{{- end }}
{{- end }}
