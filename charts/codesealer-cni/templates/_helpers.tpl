{{/*
Expand the name of the chart.
*/}}
{{- define "codesealer-cni.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "codesealer-cni.fullname" -}}
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
{{- define "codesealer-cni.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "codesealer-cni.labels" -}}
helm.sh/chart: {{ include "codesealer-cni.chart" . }}
{{ include "codesealer-cni.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
release: {{ .Release.Name }}
codesealer.com/rev: {{ .Values.revision | default "default" }}
install.operator.codesealer.com/owning-resource: {{ .Values.ownerName | default "unknown" }}
operator.codesealer.com/component: "Cni"
{{- end }}

{{/*
Selector labels
*/}}
{{- define "codesealer-cni.selectorLabels" -}}
app.kubernetes.io/name: {{ include "codesealer-cni.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app: {{ include "codesealer-cni.name" . }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "codesealer-cni.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "codesealer-cni.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}
