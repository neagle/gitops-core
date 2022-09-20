// k8s manifests for Prometheus

package greymatter

import (
	appsv1 "k8s.io/api/apps/v1"
	corev1 "k8s.io/api/core/v1"
	rbacv1 "k8s.io/api/rbac/v1"
	"strings"
)

let Name = "prometheus"

prometheus: [
	appsv1.#StatefulSet & {
		apiVersion: "apps/v1"
		kind:       "StatefulSet"
		metadata: {
			name:      Name
			namespace: mesh.spec.install_namespace
		}
		spec: {
			serviceName: Name
			selector: {
				matchLabels: {"greymatter.io/cluster": Name}
			}
			template: {
				metadata: {
					labels: {
						"greymatter.io/cluster":  Name
						"greymatter.io/workload": "\(config.operator_namespace).\(mesh.metadata.name).\(Name)"
					}
				}
				spec: #spire_permission_requests & {
					securityContext: {
						runAsUser:  2000
						runAsGroup: 0
						fsGroup:    2000
					}
					containers: [

						#sidecar_container_block & {_Name: Name},

						{
							name:  "prometheus"
							image: mesh.spec.images.prometheus
							ports: [{
								name:          "http"
								containerPort: 9090
							}]
							command: ["/bin/prometheus"]
							args: [
								"--query.timeout=4m",
								"--query.max-samples=5000000000",
								"--storage.tsdb.path=/var/lib/prometheus/data/data",
								"--config.file=/etc/prometheus/prometheus.yaml",
								"--web.console.libraries=/usr/share/prometheus/console_libraries",
								"--web.console.templates=/usr/share/prometheus/consoles",
								"--web.enable-admin-api",
								"--web.external-url=http://anything/services/prometheus",
								"--web.route-prefix=/",
							]
							imagePullPolicy: defaults.image_pull_policy
							volumeMounts: [
								{
									name:      "\(Name)-configuration"
									mountPath: "/etc/prometheus"
								},
								{
									name:      "\(config.operator_namespace)-\(Name)-data"
									mountPath: "/var/lib/prometheus/data"
								},
							]
							resources: {
								limits: {cpu: "500m", memory: "2Gi"}
								requests: {cpu: "200m", memory: "1Gi"}

							}
						},

					]

					volumes: [
							{
							name: "\(Name)-configuration"
							configMap: {name: Name}
						},

					] + #sidecar_volumes
					imagePullSecrets: [{name: defaults.image_pull_secret_name}]
					serviceAccountName: Name
				}
			}
			volumeClaimTemplates: [
				{
					apiVersion: "v1"
					kind:       "PersistentVolumeClaim"
					metadata: name: "\(config.operator_namespace)-\(Name)-data"
					spec: {
						accessModes: ["ReadWriteOnce"]
						resources: requests: storage: "40Gi"
					}
				},
			]
		}
	},

	corev1.#ServiceAccount & {
		apiVersion: "v1"
		kind:       "ServiceAccount"
		metadata: {
			name:      Name
			namespace: mesh.spec.install_namespace
		}
	},

	rbacv1.#ClusterRole & {
		apiVersion: "rbac.authorization.k8s.io/v1"
		kind:       "ClusterRole"
		metadata: name: "\(config.operator_namespace)-\(Name)"
		rules: [{
			apiGroups: [""]
			resources: ["pods"]
			verbs: ["get", "list", "watch"]
		}]
	},

	rbacv1.#ClusterRoleBinding & {
		apiVersion: "rbac.authorization.k8s.io/v1"
		kind:       "ClusterRoleBinding"
		metadata: {
			name:      "\(config.operator_namespace)-\(Name)-clusterrolebinding"
			namespace: mesh.spec.install_namespace
		}
		subjects: [{
			kind:      "ServiceAccount"
			name:      Name
			namespace: mesh.spec.install_namespace
		}]
		roleRef: {
			kind:     "ClusterRole"
			name:     "\(config.operator_namespace)-\(Name)"
			apiGroup: "rbac.authorization.k8s.io"
		}
	},

	corev1.#ConfigMap & {
		apiVersion: "v1"
		kind:       "ConfigMap"
		metadata: {
			name:      Name
			namespace: mesh.spec.install_namespace
		}
		data: {
			"prometheus.yaml": """
      global:
        scrape_interval:     5s
        evaluation_interval: 2m

      # References the recording rules YAML file below
      rule_files:
        - "/etc/prometheus/recording_rules.yaml"

      scrape_configs:
        - job_name: 'prometheus'
          static_configs:
            - targets: ['localhost:9090']
        - job_name: 'gm-metrics-kubernetes'
          metrics_path: /prometheus
          kubernetes_sd_configs:
            - role: pod
              namespaces:
                names: [\(strings.Join([mesh.spec.install_namespace]+mesh.spec.watch_namespaces, ","))]
          relabel_configs:
          # Drop all named ports that are not "metrics"
          - source_labels: ['__meta_kubernetes_pod_container_port_name']
            regex: 'metrics'
            action: 'keep'
          # Relabel Jobs to the service name and version of the zk path
          - source_labels: ['__meta_kubernetes_pod_label_greymatter_io_cluster']
            regex: '(.*)'
            target_label:  'job'
            #replacement:   '${1}'
            replacement:   '${1}'
        - job_name: 'envoy-metrics-kubernetes'
          metrics_path: /stats/prometheus
          kubernetes_sd_configs:
            - role: pod
              namespaces:
                names: [\(strings.Join([mesh.spec.install_namespace]+mesh.spec.watch_namespaces, ","))]
          relabel_configs:
          # Drop all named ports that are not "metrics"
          - source_labels: ['__meta_kubernetes_pod_container_port_name']
            regex: 'metrics'
            action: 'keep'
          # Relabel Jobs to the service name and version of the zk path
          - source_labels: ['__meta_kubernetes_pod_label_greymatter_io_cluster']
            regex: '(.*)'
            target_label:  'job'
            #replacement:   '${1}'
            replacement:   '${1}'
          - source_labels: ['__address__']
            regex: '(.*):(.*)'
            target_label:  '__address__'
            replacement:   '${1}:8001'
      """

			"recording_rules.yaml": #"""
				# Dashboard version: 6.0.1
				# time intervals:
				# ["1h", "4h", "12h"]

				groups:
				  # queries for overall services
				  - name: overviewQueries
				    rules:
				      - record: overviewQueries:avgUpPercent:avg
				        expr: avg by (job) (up)
				      # avgResponseTimeByRoute
				      - record: overviewQueries:avgResponseTimeByRoute_1h:avg
				        expr: avg(rate(http_request_duration_seconds_sum{key!="all"}[1h]) / rate(http_request_duration_seconds_count{key!="all"}[1h]) * 1000 > 0) by (job, key)
				      - record: overviewQueries:avgResponseTimeByRoute_4h:avg
				        expr: avg(rate(http_request_duration_seconds_sum{key!="all"}[4h]) / rate(http_request_duration_seconds_count{key!="all"}[4h]) * 1000 > 0) by (job, key)
				      - record: overviewQueries:avgResponseTimeByRoute_12h:avg
				        expr: avg(rate(http_request_duration_seconds_sum{key!="all"}[12h]) / rate(http_request_duration_seconds_count{key!="all"}[12h]) * 1000 > 0) by (job, key)
				        # numberOfRequestsByRoute
				      - record: overviewQueries:numberOfRequestsByRoute_1h:sum
				        expr: sum(floor(increase(http_request_duration_seconds_count[1h])) >= 1) by (job, key)
				      - record: overviewQueries:numberOfRequestsByRoute_4h:sum
				        expr: sum(floor(increase(http_request_duration_seconds_count[4h])) >= 1) by (job, key)
				      - record: overviewQueries:numberOfRequestsByRoute_12h:sum
				        expr: sum(floor(increase(http_request_duration_seconds_count[12h])) >= 1) by (job, key)
				        # latencyByRoute
				      - record: overviewQueries:latencyByRoute_1h:sum
				        expr: sum without(instance, status)(rate(http_request_duration_seconds_count{key!="all"}[1h])) > 0
				      - record: overviewQueries:latencyByRoute_4h:sum
				        expr: sum without(instance, status)(rate(http_request_duration_seconds_count{key!="all"}[4h])) > 0
				      - record: overviewQueries:latencyByRoute_12h:sum
				        expr: sum without(instance, status)(rate(http_request_duration_seconds_count{key!="all"}[12h])) > 0
				        # error percent
				      - record: overviewQueries:errorPercent_1h:sum
				        expr: sum(floor(increase(http_request_duration_seconds_count{status!~"2..|3..", key!="all"}[1h]) )) by (job) / sum(floor(increase(http_request_duration_seconds_count{key!="all"}[1h]) )) by (job) * 100
				      - record: overviewQueries:errorPercent_4h:sum
				        expr: sum(floor(increase(http_request_duration_seconds_count{status!~"2..|3..", key!="all"}[4h]) )) by (job) / sum(floor(increase(http_request_duration_seconds_count{key!="all"}[4h]) )) by (job) * 100
				      - record: overviewQueries:errorPercent_12h:sum
				        expr: sum(floor(increase(http_request_duration_seconds_count{status!~"2..|3..", key!="all"}[12h]) )) by (job) / sum(floor(increase(http_request_duration_seconds_count{key!="all"}[12h]) )) by (job) * 100
				  # queries for each route
				  - name: queriesByRoute
				    rules:
				      # error percent
				      - record: queriesByRoute:errorPercent_1h:sum
				        expr: sum(floor(increase(http_request_duration_seconds_count{status!~"2..|3..", key!="all"}[1h]) )) by (job, key, method) / sum(floor(increase(http_request_duration_seconds_count{key!="all"}[1h]) )) by (job, key, method) * 100
				      - record: queriesByRoute:errorPercent_4h:sum
				        expr: sum(floor(increase(http_request_duration_seconds_count{status!~"2..|3..", key!="all"}[4h]) )) by (job, key, method) / sum(floor(increase(http_request_duration_seconds_count{key!="all"}[4h]) )) by (job, key, method) * 100
				      - record: queriesByRoute:errorPercent_12h:sum
				        expr: sum(floor(increase(http_request_duration_seconds_count{status!~"2..|3..", key!="all"}[12h]) )) by (job, key, method) / sum(floor(increase(http_request_duration_seconds_count{key!="all"}[12h]) )) by (job, key, method) * 100
				        # p95Latency
				      - record: queriesByRoute:p95Latency_1h:sum
				        expr: round(histogram_quantile(0.95,avg without(instance, status)(rate(http_request_duration_seconds_bucket[1h]))) * 1000, 0.1)
				      - record: queriesByRoute:p95Latency_4h:sum
				        expr: round(histogram_quantile(0.95,avg without(instance, status)(rate(http_request_duration_seconds_bucket[4h]))) * 1000, 0.1)
				      - record: queriesByRoute:p95Latency_12h:sum
				        expr: round(histogram_quantile(0.95,avg without(instance, status)(rate(http_request_duration_seconds_bucket[12h]))) * 1000, 0.1)
				        # p50 latency
				      - record: queriesByRoute:p50Latency_1h:sum
				        expr: round(histogram_quantile(0.50,avg without(instance, status)(rate(http_request_duration_seconds_bucket[1h]))) * 1000, 0.1)
				      - record: queriesByRoute:p50Latency_4h:sum
				        expr: round(histogram_quantile(0.50,avg without(instance, status)(rate(http_request_duration_seconds_bucket[4h]))) * 1000, 0.1)
				      - record: queriesByRoute:p50Latency_12h:sum
				        expr: round(histogram_quantile(0.50,avg without(instance, status)(rate(http_request_duration_seconds_bucket[12h]))) * 1000, 0.1)
				        # request count for route
				      - record: queriesByRoute:requestCount_1h:sum
				        expr: sum(floor(increase(http_request_duration_seconds_count[1h])) >= 1) by (job, key, method)
				      - record: queriesByRoute:requestCount_4h:sum
				        expr: sum(floor(increase(http_request_duration_seconds_count[4h])) >= 1) by (job, key, method)
				      - record: queriesByRoute:requestCount_12h:sum
				        expr: sum(floor(increase(http_request_duration_seconds_count[12h])) >= 1) by (job, key, method)
				    
				  # range queries
				  - name: rangeQueries
				    rules:
				      # pXXLatency range queries
				      - record: rangeQueries:p50Latency:sum
				        expr: round(histogram_quantile(0.50,avg without(instance, status)(rate(http_request_duration_seconds_bucket[10m]))) * 1000, 0.1)
				      - record: rangeQueries:p90Latency:sum
				        expr: round(histogram_quantile(0.90,avg without(instance, status)(rate(http_request_duration_seconds_bucket[10m]))) * 1000, 0.1)
				      - record: rangeQueries:p95Latency:sum
				        expr: round(histogram_quantile(0.95,avg without(instance, status)(rate(http_request_duration_seconds_bucket[10m]))) * 1000, 0.1)
				      - record: rangeQueries:p99Latency:sum
				        expr: round(histogram_quantile(0.99,avg without(instance, status)(rate(http_request_duration_seconds_bucket[10m]))) * 1000, 0.1)
				      - record: rangeQueries:p999Latency:sum
				        expr: round(histogram_quantile(0.999,avg without(instance, status)(rate(http_request_duration_seconds_bucket[10m]))) * 1000, 0.1)
				      - record: rangeQueries:p9999Latency:sum
				        expr: round(histogram_quantile(0.9999,avg without(instance, status)(rate(http_request_duration_seconds_bucket[10m]))) * 1000, 0.1)
				        # error percent by (job, key)
				      - record: rangeQueries:errorPercent:sum
				        expr: sum(floor(increase(http_request_duration_seconds_count{status!~"2..|3..", key!="all"}[1m]) )) by (job, key) / sum(floor(increase(http_request_duration_seconds_count{key!="all"}[1m]) )) by (job, key) * 100
				        # respones time per bucket
				      - record: rangeQueries:responseTimeP50:sum
				        expr: round(histogram_quantile(0.50,avg without(instance, status, key, method)(rate(http_request_duration_seconds_bucket{key!="all"}[10m]))) * 1000, 0.1)
				      - record: rangeQueries:responseTimeP90:sum
				        expr: round(histogram_quantile(0.90,avg without(instance, status, key, method)(rate(http_request_duration_seconds_bucket{key!="all"}[10m]))) * 1000, 0.1)
				      - record: rangeQueries:responseTimeP95:sum
				        expr: round(histogram_quantile(0.95,avg without(instance, status, key, method)(rate(http_request_duration_seconds_bucket{key!="all"}[10m]))) * 1000, 0.1)
				      - record: rangeQueries:responseTimeP99:sum
				        expr: round(histogram_quantile(0.99,avg without(instance, status, key, method)(rate(http_request_duration_seconds_bucket{key!="all"}[10m]))) * 1000, 0.1)
				      - record: rangeQueries:responseTimeP999:sum
				        expr: round(histogram_quantile(0.999,avg without(instance, status, key, method)(rate(http_request_duration_seconds_bucket{key!="all"}[10m]))) * 1000, 0.1)
				      - record: rangeQueries:responseTimeP9999:sum
				        expr: round(histogram_quantile(0.9999,avg without(instance, status, key, method)(rate(http_request_duration_seconds_bucket{key!="all"}[10m]))) * 1000, 0.1)
				"""#
		}
	},

]

prometheus_proxy: [
	// // standalone proxy for prometheus
	appsv1.#Deployment & {
		apiVersion: "apps/v1"
		kind:       "Deployment"
		metadata: {
			name:      Name
			namespace: mesh.spec.install_namespace
		}
		spec: {
			selector: {
				matchLabels: {"greymatter.io/cluster": Name}
			}
			template: {
				metadata: {
					labels: {
						"greymatter.io/cluster":  Name
						"greymatter.io/workload": "\(config.operator_namespace).\(mesh.metadata.name).\(Name)"
					}
				}
				spec: #spire_permission_requests & {
					containers: [
						#sidecar_container_block & {
							_Name: Name
							_volume_mounts: [
								if defaults.prometheus.tls.enabled == true {
									{
										name:      "prometheus-tls-certs"
										mountPath: "/etc/proxy/tls/prometheus"
									}
								},
							]
						},
					]
					volumes: #sidecar_volumes + [
							if defaults.prometheus.tls.enabled == true {
							{
								name: "prometheus-tls-certs"
								secret: {defaultMode: 420, secretName: defaults.prometheus.tls.cert_secret}
							}
						},
					]
					imagePullSecrets: [{name: defaults.image_pull_secret_name}]
				}
			}
		}
	},
]
