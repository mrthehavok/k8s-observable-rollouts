# Helm Chart Design for Sample API

## Overview

This document outlines the Helm chart structure for the sample FastAPI application, designed to support progressive delivery with Argo Rollouts, comprehensive monitoring, and multi-environment deployments.

## Chart Structure

```
charts/sample-api/
├── Chart.yaml                      # Chart metadata
├── values.yaml                     # Default values
├── values-dev.yaml                 # Development overrides
├── values-staging.yaml             # Staging overrides
├── values-prod.yaml                # Production overrides
├── templates/
│   ├── NOTES.txt                   # Post-install notes
│   ├── _helpers.tpl                # Template helpers
│   ├── rollout.yaml                # Argo Rollout resource
│   ├── service.yaml                # Kubernetes Service
│   ├── service-preview.yaml        # Preview Service (Blue/Green)
│   ├── service-canary.yaml         # Canary Service
│   ├── ingress.yaml                # Ingress configuration
│   ├── configmap.yaml              # Application configuration
│   ├── secret.yaml                 # Sensitive configuration
│   ├── servicemonitor.yaml         # Prometheus ServiceMonitor
│   ├── analysis-template.yaml      # Argo Rollouts AnalysisTemplate
│   ├── hpa.yaml                    # HorizontalPodAutoscaler
│   ├── pdb.yaml                    # PodDisruptionBudget
│   └── tests/
│       └── test-connection.yaml    # Helm test
├── rollout-strategies/
│   ├── blue-green.yaml             # Blue/Green strategy config
│   └── canary.yaml                 # Canary strategy config
└── README.md                       # Chart documentation
```

## Chart Definition

### Chart.yaml

```yaml
apiVersion: v2
name: sample-api
description: A FastAPI sample application with progressive delivery support
type: application
version: 0.1.0
appVersion: "1.0.0"
keywords:
  - fastapi
  - argo-rollouts
  - gitops
  - observability
home: https://github.com/your-org/k8s-observable-rollouts
sources:
  - https://github.com/your-org/k8s-observable-rollouts
maintainers:
  - name: Your Name
    email: your.email@example.com
dependencies: [] # No chart dependencies, Argo Rollouts installed separately
annotations:
  # Artifacthub annotations
  artifacthub.io/changes: |
    - kind: added
      description: Initial release
  artifacthub.io/containsSecurityUpdates: "false"
  artifacthub.io/prerelease: "false"
```

### Default Values (values.yaml)

```yaml
# Default values for sample-api
# This is a YAML-formatted file.
# Declare variables to be passed into your templates.

## Global settings
global:
  ## Labels to apply to all resources
  labels: {}
  ## Annotations to apply to all resources
  annotations: {}

## Application image configuration
image:
  repository: sample-api
  pullPolicy: IfNotPresent
  # Overrides the image tag whose default is the chart appVersion.
  tag: ""

imagePullSecrets: []
nameOverride: ""
fullnameOverride: ""

## Rollout configuration
rollout:
  ## Enable Argo Rollouts (if false, uses standard Deployment)
  enabled: true

  ## Number of replicas
  replicas: 2

  ## Revision history limit
  revisionHistoryLimit: 5

  ## Rollout strategy: "blueGreen" or "canary"
  strategy: blueGreen

  ## Blue/Green specific configuration
  blueGreen:
    ## Enable auto-promotion
    autoPromotionEnabled: false
    ## Seconds before scaling down old version
    scaleDownDelaySeconds: 30
    ## Pre-promotion analysis
    prePromotionAnalysis:
      enabled: true
      templates:
        - success-rate
    ## Post-promotion analysis
    postPromotionAnalysis:
      enabled: false

  ## Canary specific configuration
  canary:
    ## Canary steps configuration
    steps:
      - setWeight: 20
      - pause: { duration: 2m }
      - analysis:
          templates:
            - success-rate
            - latency-p99
      - setWeight: 50
      - pause: { duration: 2m }
      - analysis:
          templates:
            - success-rate
            - latency-p99
      - setWeight: 100

    ## Analysis configuration
    analysis:
      ## Success rate threshold (percentage)
      successRateThreshold: 95
      ## Latency P99 threshold (milliseconds)
      latencyThreshold: 500
      ## Analysis interval
      interval: 30s
      ## Number of successful measurements required
      successfulMeasurements: 3
      ## Number of failed measurements to trigger rollback
      failureLimit: 3

## Service configuration
service:
  type: ClusterIP
  port: 80
  targetPort: 8000
  ## Additional service annotations
  annotations: {}
  ## Node port (if type is NodePort)
  # nodePort: 30080

## Ingress configuration
ingress:
  enabled: true
  className: nginx
  annotations:
    nginx.ingress.kubernetes.io/ssl-redirect: "false"
    # nginx.ingress.kubernetes.io/force-ssl-redirect: "true"
    # cert-manager.io/cluster-issuer: "letsencrypt-prod"
  hosts:
    - host: app.local
      paths:
        - path: /
          pathType: Prefix
  tls: []
  #  - secretName: app-tls
  #    hosts:
  #      - app.local

## Pod configuration
podAnnotations:
  prometheus.io/scrape: "true"
  prometheus.io/port: "8000"
  prometheus.io/path: "/metrics"

podSecurityContext:
  runAsNonRoot: true
  runAsUser: 1000
  runAsGroup: 1000
  fsGroup: 1000

securityContext:
  allowPrivilegeEscalation: false
  readOnlyRootFilesystem: true
  capabilities:
    drop:
      - ALL

## Resource limits and requests
resources:
  limits:
    cpu: 200m
    memory: 256Mi
  requests:
    cpu: 100m
    memory: 128Mi

## Autoscaling configuration
autoscaling:
  enabled: false
  minReplicas: 2
  maxReplicas: 10
  targetCPUUtilizationPercentage: 80
  targetMemoryUtilizationPercentage: 80
  ## Custom metrics for scaling
  metrics: []
  # - type: Pods
  #   pods:
  #     metric:
  #       name: http_requests_per_second
  #     target:
  #       type: AverageValue
  #       averageValue: 1k

## Pod Disruption Budget
podDisruptionBudget:
  enabled: true
  minAvailable: 1
  # maxUnavailable: 1

## Liveness and Readiness probes
livenessProbe:
  httpGet:
    path: /health/live
    port: http
  initialDelaySeconds: 10
  periodSeconds: 30
  timeoutSeconds: 5
  successThreshold: 1
  failureThreshold: 3

readinessProbe:
  httpGet:
    path: /health/ready
    port: http
  initialDelaySeconds: 5
  periodSeconds: 10
  timeoutSeconds: 5
  successThreshold: 1
  failureThreshold: 3

startupProbe:
  httpGet:
    path: /health/startup
    port: http
  initialDelaySeconds: 0
  periodSeconds: 10
  timeoutSeconds: 5
  successThreshold: 1
  failureThreshold: 30

## Node selection
nodeSelector: {}

## Tolerations
tolerations: []

## Pod affinity
affinity:
  {}
  # podAntiAffinity:
  #   preferredDuringSchedulingIgnoredDuringExecution:
  #   - weight: 100
  #     podAffinityTerm:
  #       labelSelector:
  #         matchExpressions:
  #         - key: app.kubernetes.io/name
  #           operator: In
  #           values:
  #           - sample-api
  #       topologyKey: kubernetes.io/hostname

## Application configuration
config:
  ## Application environment
  environment: "development"
  ## Log level
  logLevel: "INFO"
  ## Enable debug mode
  debug: false
  ## Application port
  port: 8000

  ## Feature flags
  features:
    slowEndpoint: true
    slowEndpointDelay: 5
    errorRate: 0

  ## Additional environment variables
  env: []
  # - name: DATABASE_URL
  #   value: "postgresql://user:pass@host:5432/db"

  ## Environment variables from secrets
  envFrom: []
  # - secretRef:
  #     name: app-secrets

## Secrets configuration
secrets:
  ## Create secret from values
  create: true
  ## External secret name (if create is false)
  # name: "existing-secret"
  ## Secret data
  data:
    {}
    # API_KEY: "your-api-key"
    # DATABASE_PASSWORD: "your-password"

## Monitoring configuration
monitoring:
  ## Enable ServiceMonitor for Prometheus
  serviceMonitor:
    enabled: true
    ## Interval at which metrics should be scraped
    interval: 30s
    ## Metrics path
    path: /metrics
    ## Additional labels for ServiceMonitor
    labels: {}
    ## Metric relabeling configurations
    metricRelabelings: []
    ## Relabeling configurations
    relabelings: []

## Dashboards configuration
dashboards:
  ## Enable Grafana dashboard ConfigMap
  enabled: true
  ## Labels for dashboard discovery
  labels:
    grafana_dashboard: "1"
  ## Annotations for dashboard ConfigMap
  annotations:
    k8s-sidecar-target-directory: "/var/lib/grafana/dashboards/sample-api"

## Tests configuration
tests:
  enabled: true
  ## Test image
  image:
    repository: busybox
    tag: latest
    pullPolicy: IfNotPresent
```

## Template Files

### 1. Helpers Template (\_helpers.tpl)

```yaml
{{/*
Expand the name of the chart.
*/}}
{{- define "sample-api.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "sample-api.fullname" -}}
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
{{- define "sample-api.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "sample-api.labels" -}}
helm.sh/chart: {{ include "sample-api.chart" . }}
{{ include "sample-api.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- with .Values.global.labels }}
{{ toYaml . }}
{{- end }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "sample-api.selectorLabels" -}}
app.kubernetes.io/name: {{ include "sample-api.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "sample-api.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "sample-api.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Define the image
*/}}
{{- define "sample-api.image" -}}
{{- $tag := .Values.image.tag | default .Chart.AppVersion -}}
{{- printf "%s:%s" .Values.image.repository $tag -}}
{{- end }}

{{/*
Define environment variables
*/}}
{{- define "sample-api.env" -}}
- name: APP_NAME
  value: {{ include "sample-api.name" . | quote }}
- name: APP_ENV
  value: {{ .Values.config.environment | quote }}
- name: LOG_LEVEL
  value: {{ .Values.config.logLevel | quote }}
- name: DEBUG
  value: {{ .Values.config.debug | quote }}
- name: PORT
  value: {{ .Values.config.port | quote }}
- name: VERSION
  value: {{ .Chart.AppVersion | quote }}
- name: ENABLE_SLOW_ENDPOINT
  value: {{ .Values.config.features.slowEndpoint | quote }}
- name: SLOW_ENDPOINT_DELAY
  value: {{ .Values.config.features.slowEndpointDelay | quote }}
- name: ERROR_RATE
  value: {{ .Values.config.features.errorRate | quote }}
{{- with .Values.config.env }}
{{ toYaml . }}
{{- end }}
{{- end }}
```

### 2. Rollout Template (rollout.yaml)

```yaml
{{- if .Values.rollout.enabled }}
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: {{ include "sample-api.fullname" . }}
  labels:
    {{- include "sample-api.labels" . | nindent 4 }}
spec:
  replicas: {{ .Values.rollout.replicas }}
  revisionHistoryLimit: {{ .Values.rollout.revisionHistoryLimit }}
  selector:
    matchLabels:
      {{- include "sample-api.selectorLabels" . | nindent 6 }}
  template:
    metadata:
      annotations:
        checksum/config: {{ include (print $.Template.BasePath "/configmap.yaml") . | sha256sum }}
        {{- with .Values.podAnnotations }}
        {{- toYaml . | nindent 8 }}
        {{- end }}
      labels:
        {{- include "sample-api.selectorLabels" . | nindent 8 }}
    spec:
      {{- with .Values.imagePullSecrets }}
      imagePullSecrets:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      securityContext:
        {{- toYaml .Values.podSecurityContext | nindent 8 }}
      containers:
        - name: {{ .Chart.Name }}
          securityContext:
            {{- toYaml .Values.securityContext | nindent 12 }}
          image: {{ include "sample-api.image" . }}
          imagePullPolicy: {{ .Values.image.pullPolicy }}
          ports:
            - name: http
              containerPort: {{ .Values.config.port }}
              protocol: TCP
          livenessProbe:
            {{- toYaml .Values.livenessProbe | nindent 12 }}
          readinessProbe:
            {{- toYaml .Values.readinessProbe | nindent 12 }}
          startupProbe:
            {{- toYaml .Values.startupProbe | nindent 12 }}
          resources:
            {{- toYaml .Values.resources | nindent 12 }}
          env:
            {{- include "sample-api.env" . | nindent 12 }}
          {{- if .Values.config.envFrom }}
          envFrom:
            {{- toYaml .Values.config.envFrom | nindent 12 }}
          {{- end }}
          {{- if .Values.secrets.create }}
          envFrom:
            - secretRef:
                name: {{ include "sample-api.fullname" . }}
          {{- else if .Values.secrets.name }}
          envFrom:
            - secretRef:
                name: {{ .Values.secrets.name }}
          {{- end }}
          volumeMounts:
            - name: tmp
              mountPath: /tmp
              readOnly: false
      volumes:
        - name: tmp
          emptyDir: {}
      {{- with .Values.nodeSelector }}
      nodeSelector:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with .Values.affinity }}
      affinity:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with .Values.tolerations }}
      tolerations:
        {{- toYaml . | nindent 8 }}
      {{- end }}
  strategy:
    {{- if eq .Values.rollout.strategy "blueGreen" }}
    blueGreen:
      activeService: {{ include "sample-api.fullname" . }}
      previewService: {{ include "sample-api.fullname" . }}-preview
      autoPromotionEnabled: {{ .Values.rollout.blueGreen.autoPromotionEnabled }}
      scaleDownDelaySeconds: {{ .Values.rollout.blueGreen.scaleDownDelaySeconds }}
      {{- if .Values.rollout.blueGreen.prePromotionAnalysis.enabled }}
      prePromotionAnalysis:
        templates:
        {{- range .Values.rollout.blueGreen.prePromotionAnalysis.templates }}
        - templateName: {{ . }}
        {{- end }}
      {{- end }}
      {{- if .Values.rollout.blueGreen.postPromotionAnalysis.enabled }}
      postPromotionAnalysis:
        templates:
        {{- range .Values.rollout.blueGreen.postPromotionAnalysis.templates }}
        - templateName: {{ . }}
        {{- end }}
      {{- end }}
    {{- else if eq .Values.rollout.strategy "canary" }}
    canary:
      canaryService: {{ include "sample-api.fullname" . }}-canary
      stableService: {{ include "sample-api.fullname" . }}
      {{- if .Values.ingress.enabled }}
      trafficRouting:
        nginx:
          stableIngress: {{ include "sample-api.fullname" . }}
      {{- end }}
      {{- with .Values.rollout.canary.steps }}
      steps:
        {{- toYaml . | nindent 8 }}
      {{- end }}
    {{- end }}
{{- end }}
```

### 3. Service Templates

**service.yaml**:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: {{ include "sample-api.fullname" . }}
  labels:
    {{- include "sample-api.labels" . | nindent 4 }}
  {{- with .Values.service.annotations }}
  annotations:
    {{- toYaml . | nindent 4 }}
  {{- end }}
spec:
  type: {{ .Values.service.type }}
  ports:
    - port: {{ .Values.service.port }}
      targetPort: http
      protocol: TCP
      name: http
      {{- if and (eq .Values.service.type "NodePort") .Values.service.nodePort }}
      nodePort: {{ .Values.service.nodePort }}
      {{- end }}
  selector:
    {{- include "sample-api.selectorLabels" . | nindent 4 }}
```

**service-preview.yaml** (for Blue/Green):

```yaml
{{- if and .Values.rollout.enabled (eq .Values.rollout.strategy "blueGreen") }}
apiVersion: v1
kind: Service
metadata:
  name: {{ include "sample-api.fullname" . }}-preview
  labels:
    {{- include "sample-api.labels" . | nindent 4 }}
    app.kubernetes.io/component: preview
spec:
  type: {{ .Values.service.type }}
  ports:
    - port: {{ .Values.service.port }}
      targetPort: http
      protocol: TCP
      name: http
  selector:
    {{- include "sample-api.selectorLabels" . | nindent 4 }}
{{- end }}
```

**service-canary.yaml** (for Canary):

```yaml
{{- if and .Values.rollout.enabled (eq .Values.rollout.strategy "canary") }}
apiVersion: v1
kind: Service
metadata:
  name: {{ include "sample-api.fullname" . }}-canary
  labels:
    {{- include "sample-api.labels" . | nindent 4 }}
    app.kubernetes.io/component: canary
spec:
  type: {{ .Values.service.type }}
  ports:
    - port: {{ .Values.service.port }}
      targetPort: http
      protocol: TCP
      name: http
  selector:
    {{- include "sample-api.selectorLabels" . | nindent 4 }}
{{- end }}
```

### 4. Analysis Template (analysis-template.yaml)

```yaml
{{- if .Values.rollout.enabled }}
---
apiVersion: argoproj.io/v1alpha1
kind: AnalysisTemplate
metadata:
  name: success-rate
  labels:
    {{- include "sample-api.labels" . | nindent 4 }}
spec:
  metrics:
  - name: success-rate
    interval: {{ .Values.rollout.canary.analysis.interval }}
    successCondition: result[0] >= {{ .Values.rollout.canary.analysis.successRateThreshold }}
    failureLimit: {{ .Values.rollout.canary.analysis.failureLimit }}
    provider:
      prometheus:
        address: http://kube-prometheus-stack-prometheus.monitoring:9090
        query: |
          sum(rate(
            http_requests_total{
              app_kubernetes_io_name="{{ include "sample-api.name" . }}",
              app_kubernetes_io_instance="{{ .Release.Name }}",
              status!~"5.."
            }[2m]
          )) /
          sum(rate(
            http_requests_total{
              app_kubernetes_io_name="{{ include "sample-api.name" . }}",
              app_kubernetes_io_instance="{{ .Release.Name }}"
            }[2m]
          )) * 100
---
apiVersion: argoproj.io/v1alpha1
kind: AnalysisTemplate
metadata:
  name: latency-p99
  labels:
    {{- include "sample-api.labels" . | nindent 4 }}
spec:
  metrics:
  - name: latency-p99
    interval: {{ .Values.rollout.canary.analysis.interval }}
    successCondition: result[0] <= {{ .Values.rollout.canary.analysis.latencyThreshold }}
    failureLimit: {{ .Values.rollout.canary.analysis.failureLimit }}
    provider:
      prometheus:
        address: http://kube-prometheus-stack-prometheus.monitoring:9090
        query: |
          histogram_quantile(0.99,
            sum(rate(
              http_request_duration_seconds_bucket{
                app_kubernetes_io_name="{{ include "sample-api.name" . }}",
                app_kubernetes_io_instance="{{ .Release.Name }}"
              }[2m]
            )) by (le)
          ) * 1000
{{- end }}
```

### 5. ConfigMap Template (configmap.yaml)

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ include "sample-api.fullname" . }}-config
  labels:
    {{- include "sample-api.labels" . | nindent 4 }}
data:
  app-config.yaml: |
    app:
      name: {{ include "sample-api.name" . }}
      environment: {{ .Values.config.environment }}
      version: {{ .Chart.AppVersion }}
    features:
      slow_endpoint: {{ .Values.config.features.slowEndpoint }}
      slow_delay: {{ .Values.config.features.slowEndpointDelay }}
      error_rate: {{ .Values.config.features.errorRate }}
    logging:
      level: {{ .Values.config.logLevel }}
      format: json
```

### 6. ServiceMonitor Template (servicemonitor.yaml)

```yaml
{{- if .Values.monitoring.serviceMonitor.enabled }}
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: {{ include "sample-api.fullname" . }}
  labels:
    {{- include "sample-api.labels" . | nindent 4 }}
    {{- with .Values.monitoring.serviceMonitor.labels }}
    {{- toYaml . | nindent 4 }}
    {{- end }}
spec:
  selector:
    matchLabels:
      {{- include "sample-api.selectorLabels" . | nindent 6 }}
  endpoints:
  - port: http
    interval: {{ .Values.monitoring.serviceMonitor.interval }}
    path: {{ .Values.monitoring.serviceMonitor.path }}
    {{- with .Values.monitoring.serviceMonitor.metricRelabelings }}
    metricRelabelings:
      {{- toYaml . | nindent 6 }}
    {{- end }}
    {{- with .Values.monitoring.serviceMonitor.relabelings }}
    relabelings:
      {{- toYaml . | nindent 6 }}
    {{- end }}
{{- end }}
```

### 7. HorizontalPodAutoscaler (hpa.yaml)

```yaml
{{- if .Values.autoscaling.enabled }}
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: {{ include "sample-api.fullname" . }}
  labels:
    {{- include "sample-api.labels" . | nindent 4 }}
spec:
  scaleTargetRef:
    apiVersion: argoproj.io/v1alpha1
    kind: Rollout
    name: {{ include "sample-api.fullname" . }}
  minReplicas: {{ .Values.autoscaling.minReplicas }}
  maxReplicas: {{ .Values.autoscaling.maxReplicas }}
  metrics:
  {{- if .Values.autoscaling.targetCPUUtilizationPercentage }}
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: {{ .Values.autoscaling.targetCPUUtilizationPercentage }}
  {{- end }}
  {{- if .Values.autoscaling.targetMemoryUtilizationPercentage }}
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: {{ .Values.autoscaling.targetMemoryUtilizationPercentage }}
  {{- end }}
  {{- with .Values.autoscaling.metrics }}
  {{- toYaml . | nindent 2 }}
  {{- end }}
{{- end }}
```

### 8. PodDisruptionBudget (pdb.yaml)

```yaml
{{- if .Values.podDisruptionBudget.enabled }}
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: {{ include "sample-api.fullname" . }}
  labels:
    {{- include "sample-api.labels" . | nindent 4 }}
spec:
  {{- if .Values.podDisruptionBudget.minAvailable }}
  minAvailable: {{ .Values.podDisruptionBudget.minAvailable }}
  {{- end }}
  {{- if .Values.podDisruptionBudget.maxUnavailable }}
  maxUnavailable: {{ .Values.podDisruptionBudget.maxUnavailable }}
  {{- end }}
  selector:
    matchLabels:
      {{- include "sample-api.selectorLabels" . | nindent 6 }}
{{- end }}
```

### 9. NOTES.txt

```
1. Get the application URL by running these commands:
{{- if .Values.ingress.enabled }}
{{- range $host := .Values.ingress.hosts }}
  {{- range .paths }}
  http{{ if $.Values.ingress.tls }}s{{ end }}://{{ $host.host }}{{ .path }}
  {{- end }}
{{- end }}
{{- else if contains "NodePort" .Values.service.type }}
  export NODE_PORT=$(kubectl get --namespace {{ .Release.Namespace }} -o jsonpath="{.spec.ports[0].nodePort}" services {{ include "sample-api.fullname" . }})
  export NODE_IP=$(kubectl get nodes --namespace {{ .Release.Namespace }} -o jsonpath="{.items[0].status.addresses[0].address}")
  echo http://$NODE_IP:$NODE_PORT
{{- else if contains "LoadBalancer" .Values.service.type }}
     NOTE: It may take a few minutes for the LoadBalancer IP to be available.
           You can watch the status of by running 'kubectl get --namespace {{ .Release.Namespace }} svc -w {{ include "sample-api.fullname" . }}'
  export SERVICE_IP=$(kubectl get svc --namespace {{ .Release.Namespace }} {{ include "sample-api.fullname" . }} --template "{{"{{ range (index .status.loadBalancer.ingress 0) }}{{.}}{{ end }}"}}")
  echo http://$SERVICE_IP:{{ .Values.service.port }}
{{- else if contains "ClusterIP" .Values.service.type }}
  export POD_NAME=$(kubectl get pods --namespace {{ .Release.Namespace }} -l "app.kubernetes.io/name={{ include "sample-api.name" . }},app.kubernetes.io/instance={{ .Release.Name }}" -o jsonpath="{.items[0].metadata.name}")
  export CONTAINER_PORT=$(kubectl get pod --namespace {{ .Release.Namespace }} $POD_NAME -o jsonpath="{.spec.containers[0].ports[0].containerPort}")
  echo "Visit http://127.0.0.1:8080 to use your application"
  kubectl --namespace {{ .Release.Namespace }} port-forward $POD_NAME 8080:$CONTAINER_PORT
{{- end }}

2. Check the rollout status:
{{- if .Values.rollout.enabled }}
  kubectl argo rollouts get rollout {{ include "sample-api.fullname" . }} -n {{ .Release.Namespace }}
{{- else }}
  kubectl rollout status deployment/{{ include "sample-api.fullname" . }} -n {{ .Release.Namespace }}
{{- end }}

3. View application metrics:
  Prometheus metrics are available at: http://{{ include "sample-api.fullname" . }}.{{ .Release.Namespace }}:{{ .Values.service.port }}/metrics

{{- if .Values.monitoring.serviceMonitor.enabled }}
4. Grafana dashboards:
  The application dashboard should be automatically imported into Grafana.
{{- end }}
```

## Environment-Specific Values

### Development (values-dev.yaml)

```yaml
## Development environment overrides
config:
  environment: "development"
  logLevel: "DEBUG"
  debug: true
  features:
    slowEndpoint: true
    slowEndpointDelay: 2
    errorRate: 5 # 5% error rate for testing

rollout:
  replicas: 1
  strategy: blueGreen
  blueGreen:
    autoPromotionEnabled: true # Auto-promote in dev

resources:
  limits:
    cpu: 100m
    memory: 128Mi
  requests:
    cpu: 50m
    memory: 64Mi

autoscaling:
  enabled: false
```

### Staging (values-staging.yaml)

```yaml
## Staging environment overrides
config:
  environment: "staging"
  logLevel: "INFO"
  debug: false
  features:
    slowEndpoint: true
    slowEndpointDelay: 3
    errorRate: 0

rollout:
  replicas: 2
  strategy: canary
  canary:
    steps:
      - setWeight: 20
      - pause: { duration: 1m }
      - setWeight: 50
      - pause: { duration: 1m }
      - setWeight: 100

resources:
  limits:
    cpu: 200m
    memory: 256Mi
  requests:
    cpu: 100m
    memory: 128Mi

autoscaling:
  enabled: true
  minReplicas: 2
  maxReplicas: 5
```

### Production (values-prod.yaml)

```yaml
## Production environment overrides
config:
  environment: "production"
  logLevel: "WARNING"
  debug: false
  features:
    slowEndpoint: false
    errorRate: 0

rollout:
  replicas: 3
  strategy: canary
  canary:
    steps:
      - setWeight: 10
      - pause: { duration: 5m }
      - analysis:
          templates:
            - success-rate
            - latency-p99
      - setWeight: 25
      - pause: { duration: 5m }
      - analysis:
          templates:
            - success-rate
            - latency-p99
      - setWeight: 50
      - pause: { duration: 5m }
      - analysis:
          templates:
            - success-rate
            - latency-p99
      - setWeight: 100

resources:
  limits:
    cpu: 500m
    memory: 512Mi
  requests:
    cpu: 250m
    memory: 256Mi

autoscaling:
  enabled: true
  minReplicas: 3
  maxReplicas: 20
  targetCPUUtilizationPercentage: 70
  targetMemoryUtilizationPercentage: 80

podDisruptionBudget:
  enabled: true
  minAvailable: 2

ingress:
  annotations:
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
  hosts:
    - host: api.example.com
      paths:
        - path: /
          pathType: Prefix
  tls:
    - secretName: api-tls
      hosts:
        - api.example.com
```

## Testing the Chart

### Helm Test (test-connection.yaml)

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: "{{ include "sample-api.fullname" . }}-test-connection"
  labels:
    {{- include "sample-api.labels" . | nindent 4 }}
    app.kubernetes.io/component: test
  annotations:
    "helm.sh/hook": test
spec:
  restartPolicy: Never
  containers:
    - name: test
      image: "{{ .Values.tests.image.repository }}:{{ .Values.tests.image.tag }}"
      imagePullPolicy: {{ .Values.tests.image.pullPolicy }}
      command:
        - wget
      args:
        - '--spider'
        - '-S'
        - 'http://{{ include "sample-api.fullname" . }}:{{ .Values.service.port }}/health/ready'
```

## Usage Examples

### Install with Blue/Green Strategy

```bash
helm install sample-api ./charts/sample-api \
  --namespace sample-app \
  --create-namespace \
  --values ./charts/sample-api/values.yaml \
  --values ./charts/sample-api/values-dev.yaml \
  --set rollout.strategy=blueGreen
```

### Install with Canary Strategy

```bash
helm install sample-api ./charts/sample-api \
  --namespace sample-app \
  --create-namespace \
  --values ./charts/sample-api/values.yaml \
  --values ./charts/sample-api/values-staging.yaml \
  --set rollout.strategy=canary
```

### Upgrade with New Version

```bash
helm upgrade sample-api ./charts/sample-api \
  --namespace sample-app \
  --reuse-values \
  --set image.tag=v2.0.0
```

### Run Tests

```bash
helm test sample-api --namespace sample-app
```

## Best Practices

1. **Version Management**: Always use specific image tags, never `latest`
2. **Resource Limits**: Always set resource requests and limits
3. **Security**: Use security contexts and run as non-root
4. **Monitoring**: Enable ServiceMonitor for Prometheus integration
5. **Configuration**: Use ConfigMaps for non-sensitive config
6. **Secrets**: Use Kubernetes Secrets or external secret managers
7. **Health Checks**: Implement all three probe types
8. **Labels**: Use consistent labeling for resource selection
9. **Documentation**: Keep chart README and NOTES.txt updated

## Summary

This Helm chart provides:

- Complete Kubernetes resource definitions
- Integration with Argo Rollouts for progressive delivery
- Support for both Blue/Green and Canary strategies
- Comprehensive monitoring with Prometheus
- Multi-environment configuration
- Security best practices
- Automated scaling capabilities
- Extensive customization options

The chart is designed to be production-ready while remaining flexible for development and testing environments.
