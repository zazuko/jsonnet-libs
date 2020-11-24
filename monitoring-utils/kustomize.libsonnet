{
  local k = self,

  kustomization:: {
    apiVersion: 'kustomize.config.k8s.io/v1beta1',
    kind: 'Kustomization',
  },

  namespace(ns):: {
    namespace: ns,
  },

  resources(list=[]):: {
    resources+: list,
  },

  noHash:: {
    generatorOptions+: {
      disableNameSuffixHash: true,
    },
  },

  configMap(name, cfg={}):: {
    configMapGenerator+: [{
      name: name,
    } + cfg],
  },

  labels(obj={}): {
    commonLabels+: obj,
  },
}
