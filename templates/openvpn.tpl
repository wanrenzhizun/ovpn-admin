{{- range $route := .CustomRoutes }}
# {{ $route.Description }}
push "route {{ $route.Address }} {{ $route.Mask }}"
route {{ $route.Address }} {{ $route.Mask }}
{{- end }}
