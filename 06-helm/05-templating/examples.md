# Templating Examples

## 1. Required Value

```yaml
image: {{ required "image.repository is required" .Values.image.repository }}
```

## 2. Default Fallback

```yaml
replicas: {{ .Values.replicaCount | default 1 }}
```

## 3. Range over Map

```yaml
env:
{{- range $k, $v := .Values.env }}
  - name: {{ $k }}
    value: {{ $v | quote }}
{{- end }}
```

## 4. Conditional Resource Block

```yaml
{{- if and .Values.metrics.enabled .Values.metrics.serviceMonitor.enabled }}
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
{{- end }}
```

## 5. Capabilities Check (API support)

```yaml
{{- if .Capabilities.APIVersions.Has "policy/v1/PodDisruptionBudget" }}
apiVersion: policy/v1
{{- else }}
apiVersion: policy/v1beta1
{{- end }}
kind: PodDisruptionBudget
```

## 6. Files Glob → ConfigMap

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ include "hello-app.fullname" . }}-config
data:
{{ (.Files.Glob "configs/*.conf").AsConfig | indent 2 }}
```

## 7. Multi-line String

```yaml
data:
  nginx.conf: |
{{ .Files.Get "configs/nginx.conf" | indent 4 }}
```

## 8. Reusable Helper with Arg

```gotemplate
{{- define "hello-app.image" -}}
{{- $tag := .Values.image.tag | default .Chart.AppVersion -}}
{{ .Values.image.repository }}:{{ $tag }}
{{- end }}
```

Usage: `image: {{ include "hello-app.image" . }}`

## 9. tpl Function (template a string from values)

```yaml
# values.yaml
ingress:
  hostTemplate: "{{ .Release.Name }}.example.com"

# template
host: {{ tpl .Values.ingress.hostTemplate . }}
```

## 10. Fail Fast

```yaml
{{- if and .Values.persistence.enabled (not .Values.persistence.storageClass) }}
{{- fail "persistence.storageClass must be set when persistence is enabled" }}
{{- end }}
```
