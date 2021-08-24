{
  prometheusAlerts+:: {
    groups+: [
      {
        name: 'certmanager.rules',
        rules: [
          {
            alert: 'CertificateWillExpire',
            expr: |||
              (min without (instance) (certmanager_certificate_expiration_timestamp_seconds{}) - certmanager_clock_time_seconds) / 3600 / 24 < 7
            |||,
            labels: {
              severity: 'warning',
            },
            annotations: {
              summary: 'Certificate will expire soon.',
              description: 'Certificate {{ $labels.namespace }}/{{ $labels.name }} will expire in {{ printf "%.2f" $value }} days.',
            },
          },
          {
            alert: 'CertificateExpired',
            expr: |||
              min without (instance) (certmanager_certificate_expiration_timestamp_seconds{}) < certmanager_clock_time_seconds
            |||,
            labels: {
              severity: 'critical',
            },
            annotations: {
              summary: 'Certificate expired.',
              description: |||
                Certificate {{ $labels.namespace }}/{{ $labels.name }} expired.
              |||,
            },
          },
          {
            alert: 'CertificateConditionUnknown',
            'for': '15m',
            expr: |||
              max without (condition, instance) (certmanager_certificate_ready_status{condition="Unknown"}) == 1
            |||,
            labels: {
              severity: 'warning',
            },
            annotations: {
              summary: 'Certificate in unknown state.',
              description: |||
                Certificate {{ $labels.namespace }}/{{ $labels.name }} is in an unknown state.
              |||,
            },
          },
          {
            alert: 'CertificateConditionFalse',
            'for': '15m',
            expr: |||
              max without (condition, instance) (certmanager_certificate_ready_status{condition="False"}) == 1
            |||,
            labels: {
              severity: 'warning',
            },
            annotations: {
              summary: 'Certificate not ready.',
              description: |||
                Certificate {{ $labels.namespace }}/{{ $labels.name }} is not ready.
              |||,
            },
          },
        ],
      },
    ],
  },
}
