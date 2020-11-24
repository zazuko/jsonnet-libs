local SA_PATH = '/var/run/secrets/kubernetes.io/serviceaccount';

{
  local util = self,

  sd_prefix(suffix):: '__meta_kubernetes_%s' % suffix,
  pod(suffix):: util.sd_prefix('pod_%s' % suffix),
  service(suffix):: util.sd_prefix('service_%s' % suffix),
  node(suffix):: util.sd_prefix('node_%s' % suffix),
  endpoint(suffix):: util.sd_prefix('endpoint_%s' % suffix),

  local slug(f) = std.strReplace(std.strReplace(std.strReplace(f, '-', '_'), '.', '_'), '/', '_'),

  // Usage: util.pod(util.label('k8s-app')) == '__meta_kubernetes_pod_label_k8s_app'
  annotation(annotation):: 'annotation_%s' % slug(annotation),
  label(label):: 'label_%s' % slug(label),

  // Functions to construct kubernetes_sd_* labels
  namespace:: util.sd_prefix('namespace'),
  service_name:: util.service('name'),
  pod_name:: util.pod('name'),
  pod_node_name:: util.pod('node_name'),
  node_name:: util.node('name'),
  endpoint_port_name:: util.endpoint('port_name'),

  // Utility functions for relabel_configs
  relabel:: {
    labelmap(f):: {
      action: 'labelmap',
      regex: f(util.label('(.+)')),
    },
    match(map):: {
      action: 'keep',
      separator: ';',
      regex: std.join(';', [
        map[key]
        for key in std.objectFields(map)
      ]),
      source_labels: std.objectFields(map),
    },
    replace(labels, target, replacement='$1', regex='(.*)', separator=';'):: {
      action: 'replace',
      replacement: replacement,
      regex: regex,
      source_labels: labels,
      target_label: target,
      separator: separator,
    },
    port(port):: {
      action: 'replace',
      regex: '([^:]*)(:\\d+)?',  // TODO: IPv6 support
      replacement: '$1:%d' % port,
      source_labels: ['__address__'],
      target_label: '__address__',
    },

    generic:: [util.relabel.replace([util.namespace], 'namespace')],
    pod:: util.relabel.generic + [
      util.relabel.labelmap(util.pod),
      util.relabel.replace([util.pod_name], 'pod'),
      util.relabel.replace([util.pod_node_name], 'node'),
    ],
    service:: util.relabel.generic + [
      util.relabel.labelmap(util.service),
      util.relabel.replace([util.service_name], 'service'),
    ],
    node:: [
      util.relabel.labelmap(util.node),
      util.relabel.replace([util.node_name], 'node'),
    ],
    endpoints:: util.relabel.service + [
      util.relabel.replace([util.pod_name], 'pod'),
      util.relabel.replace([util.pod_node_name], 'node'),
    ],
  },

  sd:: {
    // Preconfigured kubernetes service discovery configs
    // Also populates the relabel_configs, unless `relabel` is set to `false`.
    kubernetes(role, namespaces=null, relabel=true):: {
      kubernetes_sd_configs+: [{
        role: role,
        [if namespaces != null then 'namespaces']: {
          names: namespaces,
        },
      }],

      relabel_configs+: if role in util.relabel && relabel then util.relabel[role] else [],
    },

    static(targets):: {
      static_configs+: [{
        targets: targets,
      }],
    },
  },

  // Authenticate to the kube-apiserver with this
  kube_api:: {
    scheme: 'https',
    tls_config: {
      ca_file: SA_PATH + '/ca.crt',
    },
    bearer_token_file: SA_PATH + '/token',
    relabel_configs+: [{
      replacement: 'kubernetes.default.svc:443',
      target_label: '__address__',
    }],
  },
}
