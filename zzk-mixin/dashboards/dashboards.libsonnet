{
  grafanaDashboards+:: {
    'cert-manager.json': (import 'cert-manager.json'),
    'flux-cd.json': (import 'flux-cd.json'),
  },
}
