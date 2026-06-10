{{/*
Expand the name of the chart.
*/}}
{{- define "vantage-kubernetes-agent.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "vantage-kubernetes-agent.fullname" -}}
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
{{- define "vantage-kubernetes-agent.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "vantage-kubernetes-agent.labels" -}}
helm.sh/chart: {{ include "vantage-kubernetes-agent.chart" . }}
{{ include "vantage-kubernetes-agent.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "vantage-kubernetes-agent.selectorLabels" -}}
app.kubernetes.io/name: {{ include "vantage-kubernetes-agent.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "vantage-kubernetes-agent.serviceAccountName" -}}
{{- default (include "vantage-kubernetes-agent.fullname" .) .Values.serviceAccount.name }}
{{- end }}

{{/*
Name used for the network-collector resources (DaemonSet, ServiceAccount, RBAC).
*/}}
{{- define "vantage-kubernetes-agent.networkCollector.fullname" -}}
{{- printf "%s-network-collector" (include "vantage-kubernetes-agent.fullname" .) | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Pod selector labels for the network-collector. The `app` label MUST stay equal
to `vantage-network-collector` because the agent discovers collectors by listing
pods with the label selector `app=vantage-network-collector`.
*/}}
{{- define "vantage-kubernetes-agent.networkCollector.selectorLabels" -}}
app: vantage-network-collector
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/component: network-collector
{{- end }}
