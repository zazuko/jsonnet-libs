local p = import 'monitoring-utils/prometheus.libsonnet';

{
  local configs = self,

  cluster_components(): [
    configs.cilium(),
    configs.coredns(),
    configs.kube_apiserver(),
    configs.kubelet(),
    configs.kubelet_cadvisor(),
    configs.kubelet_resource(),
    configs.kubelet_probes(),
    configs.kube_proxy(),
  ],

  monitoring_stack(): [
    configs.prometheus(),
    configs.alertmanager(),
    configs.kube_state_metrics(),
    configs.node_exporter(),
    configs.otel(),
  ],

  common_apps(): [
    configs.ingress_nginx(),
    configs.cert_manager(),
    configs.external_dns(),
    configs.flux(),
  ],

  prometheus(namespaces=['monitoring']): p.sd.kubernetes('endpoints', namespaces=namespaces) {
    job_name: 'prometheus',
    relabel_configs+: [
      p.relabel.match({
        [p.pod(p.label('app.kubernetes.io/name'))]: 'prometheus',
        [p.endpoint_port_name]: 'http',
      }),
    ],
  },

  // Alertmanager
  alertmanager(namespaces=['monitoring']): p.sd.kubernetes('endpoints', namespaces=namespaces) {
    job_name: 'alertmanager',
    relabel_configs+: [
      p.relabel.match({
        [p.service(p.label('app.kubernetes.io/name'))]: 'alertmanager',
        [p.endpoint_port_name]: 'http',
      }),
    ],
  },

  // cilium is the network plugin used by DigitalOcean
  cilium(): p.sd.kubernetes('pod', namespaces=['kube-system']) {
    job_name: 'cilium',
    relabel_configs+: [
      p.relabel.match({
        [p.pod(p.label('k8s-app'))]: 'cilium',
        [p.pod('container_port_name')]: 'prometheus',
      }),
    ],
  },

  // CoreDNS is Kubernetes' internal DNS
  coredns(): p.sd.kubernetes('endpoints', namespaces=['kube-system']) {
    job_name: 'coredns',
    relabel_configs+: [
      p.relabel.match({
        [p.service(p.label('k8s-app'))]: 'kube-dns',
        [p.endpoint_port_name]: 'metrics',
      }),
    ],
  },

  // Kube APIServer
  kube_apiserver(): p.sd.kubernetes('endpoints', namespaces=['default'], relabel=false) + p.kube_api {
    job_name: 'kube-apiserver',
    relabel_configs+: [
      p.relabel.match({
        [p.service_name]: 'kubernetes',
        [p.endpoint_port_name]: 'https',
      }),
    ],
    metric_relabel_configs+: [
      // Drop 25 unused buckets, which makes about 9400 series
      p.relabel.match({
        __name__: 'apiserver_request_duration_seconds_bucket',
        le: '(0.15|0.25|0.3|0.35|0.4|0.45|0.6|0.7|0.8|0.9|1.25|1.5|1.75|2.5|3|3.5|4.5|6|7|8|9|15|25|30|50)',
      }, action='drop'),
    ],
  },

  // Kubelet
  kubelet(): p.sd.kubernetes('node') + p.kube_api {
    job_name: 'kubelet',
    relabel_configs+: [
      p.relabel.replace(
        [p.node_name],
        '__metrics_path__',
        replacement='/api/v1/nodes/$1/proxy/metrics',
      ),
    ],
  },

  // Cadvisor exposes metrics about the containers running on the host
  kubelet_cadvisor(): p.sd.kubernetes('node') + p.kube_api {
    job_name: 'kubelet-cadvisor',
    relabel_configs+: [
      p.relabel.replace(
        [p.node_name],
        '__metrics_path__',
        replacement='/api/v1/nodes/$1/proxy/metrics/cadvisor',
      ),
    ],
  },

  kubelet_resource(): p.sd.kubernetes('node') + p.kube_api {
    job_name: 'kubelet-resource',
    relabel_configs+: [
      p.relabel.replace(
        [p.node_name],
        '__metrics_path__',
        replacement='/api/v1/nodes/$1/proxy/metrics/resource',
      ),
    ],
  },

  kubelet_probes(): p.sd.kubernetes('node') + p.kube_api {
    job_name: 'kubelet-probes',
    relabel_configs+: [
      p.relabel.replace(
        [p.node_name],
        '__metrics_path__',
        replacement='/api/v1/nodes/$1/proxy/metrics/probes',
      ),
    ],
  },


  // kube-proxy is respondible of service network routing
  kube_proxy(): p.sd.kubernetes('pod') {
    job_name: 'kube-proxy',
    relabel_configs+: [
      p.relabel.match({
        [p.namespace]: 'kube-system',
        [p.pod(p.label('k8s-app'))]: 'kube-proxy',
      }),
      p.relabel.port(10249),
    ],
  },

  // kube-state-metrics gathers stats about the objects within the cluster
  kube_state_metrics(): p.sd.kubernetes('service', namespaces=['kube-system'], relabel=false) {
    job_name: 'kube-state-metrics',
    relabel_configs+: [
      p.relabel.match({
        [p.service(p.label('app.kubernetes.io/name'))]: 'kube-state-metrics',
      }),
    ],
  },

  // node-exporter gathers stats about the node itself
  node_exporter(namespaces=['monitoring']): p.sd.kubernetes('pod', namespaces=namespaces, relabel=false) {
    job_name: 'node-exporter',
    relabel_configs+: [
      p.relabel.match({
        [p.pod(p.label('app.kubernetes.io/name'))]: 'node-exporter',
      }),
      p.relabel.replace([p.pod_node_name], 'node'),
    ],
  },

  /***
   * Core Apps
   ***/

  // ingress-nginx is the L7 load-balancer
  ingress_nginx(namespaces=['ingress-nginx']): p.sd.kubernetes('endpoints', namespaces=namespaces, relabel=false) {
    job_name: 'ingress-nginx',
    relabel_configs+: [
      p.relabel.match({
        [p.service_name]: 'ingress-nginx-controller-metrics',
        [p.endpoint_port_name]: 'metrics',
      }),
    ],
  },

  // cert-manager gets LetsEncrypt certificates
  cert_manager(namespaces=['cert-manager']): p.sd.kubernetes('service', namespaces=namespaces, relabel=false) {
    job_name: 'cert-manager',
    relabel_configs+: [
      p.relabel.match({
        [p.service(p.label('app.kubernetes.io/name'))]: 'cert-manager',
        [p.service(p.label('app.kubernetes.io/component'))]: 'controller',
      }),
    ],
  },

  // external-dns automatically manages external DNS servers
  external_dns(namespaces=['external-dns']): p.sd.kubernetes('pod', namespaces=namespaces) {
    job_name: 'external-dns',
    relabel_configs+: [
      p.relabel.match({
        [p.pod(p.label('app.kubernetes.io/name'))]: 'external-dns',
      }),
    ],
  },

  flux(namespaces=['flux-system']): p.sd.kubernetes('pod', namespaces=namespaces, relabel=false) {
    job_name: 'flux',
    relabel_configs+: [
      p.relabel.match({
        [p.pod('container_port_name')]: 'http-prom',
      }),
    ],
  },

  otel(namespaces=['monitoring']): p.sd.kubernetes('pod', namespaces=namespaces, relabel=false) {
    job_name: 'opentelemetry',
    relabel_configs+: [
      p.relabel.match({
        [p.pod(p.label('app.kubernetes.io/name'))]: 'opentelemetry',
        [p.pod('container_port_name')]: 'metrics-http',
      }),
    ],
  },
}
