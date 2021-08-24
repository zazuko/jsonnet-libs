{
  prometheusAlerts+:: {
    groups+: [
      {
        name: 'general.rules',
        rules: [
          {
            alert: 'TargetDown',
            expr: |||
              count by(job) (up == 0) > 0
            |||,
            'for': '10m',
            labels: {
              severity: 'warning',
            },
            annotations: {
              summary: 'Monitoring targets are down',
              description: '{{ $value }} targets of {{ $labels.job }} are down.',
            },
          },
          {
            alert: 'Watchdog',
            expr: |||
              vector(1)
            |||,
            labels: {
              severity: 'none',
            },
            annotations: {
              summary: 'Always triggering alert',
              description: |||
                This is an alert meant to ensure that the entire alerting pipeline is functional.
                This alert is always firing, therefore it should always be firing in Alertmanager
                and always fire against a receiver. There are integrations with various notification
                mechanisms that send a notification when this alert is not firing. For example the
                "DeadMansSnitch" integration in PagerDuty.
              |||,
            },
          },
        ],
      },
    ],
  },
}
