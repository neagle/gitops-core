// k8s manifests for Vector

package greymatter

import (
	appsv1 "k8s.io/api/apps/v1"
	corev1 "k8s.io/api/core/v1"
	rbacv1 "k8s.io/api/rbac/v1"
	"strings"
)

let Name = "vector-agent"
let logs_namespaces = [mesh.spec.install_namespace] + mesh.spec.watch_namespaces
let logs = strings.Join([ for namespace in logs_namespaces {"'/var/log/pods/\(namespace)*/sidecar/*.log'"}], ",")

// vector_permissions need to be applied by the user. They will be used by
// operator_manifests in k8s/EXTRACTME.cue.
vector_permissions: [
	corev1.#Namespace & {
		apiVersion: "v1"
		kind:       "Namespace"
		metadata: {
			labels: name: mesh.spec.install_namespace
			name: mesh.spec.install_namespace
		}
	},

	corev1.#ServiceAccount & {
		apiVersion:                   "v1"
		automountServiceAccountToken: true
		kind:                         "ServiceAccount"
		metadata: {
			name:      Name
			namespace: mesh.spec.install_namespace
			labels: {
				"app.kubernetes.io/instance": Name
				"app.kubernetes.io/name":     Name
				"app.kubernetes.io/part-of":  Name
				"app.kubernetes.io/version":  "0.0.0"
			}
		}
	},

	rbacv1.#ClusterRole & {
		apiVersion: "rbac.authorization.k8s.io/v1"
		kind:       "ClusterRole"
		metadata: name: "\(config.operator_namespace)-\(Name)"
		rules: [{
			apiGroups: [""]
			resources: ["pods", "namespaces"]
			verbs: ["list", "watch"]
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
]

// vector configs are applied by the operator when the mesh is installed.
vector: [
	appsv1.#DaemonSet & {
		apiVersion: "apps/v1"
		kind:       "DaemonSet"
		metadata: {
			labels: {
				"app.kubernetes.io/instance": Name
				"app.kubernetes.io/name":     Name
				"app.kubernetes.io/part-of":  Name
				"app.kubernetes.io/version":  "0.0.0"
			}
			name:      Name
			namespace: mesh.spec.install_namespace
		}
		spec: {
			minReadySeconds: 1
			selector: {
				matchLabels: {
					"app.kubernetes.io/instance": Name
					"app.kubernetes.io/name":     Name
				}
			}
			template: {
				metadata: {
					labels: {
						"app.kubernetes.io/instance": Name
						"app.kubernetes.io/name":     Name
						"vector.dev/exclude":         "true"
					}
				}
				spec: {
					containers: [{
						args: ["--config-dir", "/etc/vector/"]
						command: []
						env: [{
							name: "VECTOR_SELF_NODE_NAME"
							valueFrom: {
								fieldRef: {
									fieldPath: "spec.nodeName"
								}
							}
						}, {
							name: "VECTOR_SELF_POD_NAME"
							valueFrom: {
								fieldRef: {
									fieldPath: "metadata.name"
								}
							}
						}, {
							name: "VECTOR_SELF_POD_NAMESPACE"
							valueFrom: {
								fieldRef: {
									fieldPath: "metadata.namespace"
								}
							}
						}, {
							name:  "PROCFS_ROOT"
							value: "/host/proc"
						}, {
							name:  "SYSFS_ROOT"
							value: "/host/sys"
						}, {
							name:  "LOG"
							value: "info"
						}, {
							name: "ELASTICSEARCH_PASSWORD"
							valueFrom: {
								secretKeyRef: {
									key:  "password"
									name: "elasticsearch-password"
								}
							}
						}]
						image:           defaults.images.vector
						imagePullPolicy: defaults.image_pull_policy
						name:            Name
						ports: [{
							containerPort: 9090
							name:          "metrics"
							protocol:      "TCP"
						}]
						volumeMounts: [{
							mountPath: "/var/log/"
							name:      "var-log"
							readOnly:  true
						}, {
							mountPath: "/var/lib"
							name:      "var-lib"
							readOnly:  true
						}, {
							mountPath: "/vector-data-dir"
							name:      "data-dir"
						}, {
							mountPath: "/etc/vector"
							name:      "config-dir"
							readOnly:  true
						}, {
							mountPath: "/host/proc"
							name:      "procfs"
							readOnly:  true
						}, {
							mountPath: "/host/sys"
							name:      "sysfs"
							readOnly:  true
						}]
						resources: {
							requests: {
								memory: "64Mi"
								cpu:    "500m"
							}
							limits: {
								memory: "1024Mi"
								cpu:    "6000m"
							}
						}
					}]
					serviceAccountName:            Name
					terminationGracePeriodSeconds: 60
					tolerations: [{
						effect: "NoSchedule"
						key:    "node-role.kubernetes.io/master"
					}]
					volumes: [{
						hostPath: {
							path: "/var/log/"
						}
						name: "var-log"
					}, {
						hostPath: {
							path: "/var/lib/"
						}
						name: "var-lib"
					}, {
						hostPath: {
							path: "/var/lib/vector/"
						}
						name: "data-dir"
					}, {
						name: "config-dir"
						projected: {
							sources: [{
								configMap: {
									name: Name
								}
							}, {
								configMap: {
									name:     "\(Name)-config"
									optional: true
								}
							}, {
								secret: {
									name:     "\(Name)-config"
									optional: true
								}
							}]
						}
					}, {
						hostPath: {
							path: "/proc"
						}
						name: "procfs"
					}, {
						hostPath: {
							path: "/sys"
						}
						name: "sysfs"
					}]
				}
			}
			updateStrategy: {
				rollingUpdate: {
					maxUnavailable: 1
				}
				type: "RollingUpdate"
			}
		}
	},

	corev1.#ConfigMap & {
		apiVersion: "v1"
		kind:       "ConfigMap"
		metadata: {
			name:      "\(Name)-config"
			namespace: mesh.spec.install_namespace
		}
		data: {
			"vector.toml": """
			# Configure the source of logs.
			[sources.file]
			type = \"file\"
			include = [\(logs)]
			ignore_older = 1200
			# You can enable log file deletion if you have full control of the file.
			# Does not work with Kubernetes logs but will work with greymatter sidecar
			# logs if writing to a file instead of standard out.
			# remove_after_secs = 3600

			# Parse the log for the eventId string, indicating that it is a
			# greymatter observable log.
			[transforms.observables_only]
			type = \"filter\"
			inputs = [\"file\"]
			condition = '''
			. |= parse_regex!(.message, r'(?P<obsMatch>eventId)')
			. = .obsMatch != null
			'''

			# Parse observable JSON out of the Kubernetes log, and coerce the timestamp
			# value from ms to an actual timestamp.
			[transforms.modify]
			type = \"remap\"
			inputs = [\"observables_only\"]
			source = '''
			. |= parse_regex!(.message, r'^\\d+-\\d+-\\d+T\\d+:\\d+:\\d+.\\d+Z stdout F (?P<event>.*)$')
			. = parse_json!(.event)
			.timestamp, err = to_timestamp(.timestamp)
			'''

			# Configure Elasticsearch sink.
			[sinks.es]
			type = \"elasticsearch\"
			inputs = [\"modify\"]
			endpoint = "\(defaults.audits.elasticsearch_endpoint)"
			mode = \"bulk\"
			bulk.index = "\(defaults.audits.index)"
			compression = \"none\"
			auth.strategy = \"basic\"
			auth.user = \"elastic\"
			auth.password = \"${ELASTICSEARCH_PASSWORD}\"
			suppress_type_name = true
			"""
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
			"managed.toml": """
				# Configuration for vector.
				# Docs: https://vector.dev/docs/

				data_dir = \"/vector-data-dir\"

				[api]
				enabled = false
				address = \"0.0.0.0:8686\"
				playground = true

				[log_schema]
				host_key = \"host\"
				message_key = \"message\"
				source_type_key = \"source_type\"
				timestamp_key = \"timestamp\"

				# Ingest logs from Kubernetes.
				[sources.kubernetes_logs]
				type = \"kubernetes_logs\"

				# Capture the metrics from the host.
				[sources.host_metrics]
				type = \"host_metrics\"
				[sources.host_metrics.filesystem]
				[sources.host_metrics.filesystem.devices]
				excludes = [\"binfmt_misc\"]
				[sources.host_metrics.filesystem.filesystems]
				excludes = [\"binfmt_misc\"]
				[sources.host_metrics.filesystem.mountpoints]
				excludes = [\"*/proc/sys/fs/binfmt_misc\"]

				# Emit internal Vector metrics.
				[sources.internal_metrics]
				type = \"internal_metrics\"

				# Expose metrics for scraping in the Prometheus format.
				#[sinks.prometheus_sink]
				#address = \"0.0.0.0:9090\"
				#inputs = [\"internal_metrics\", \"host_metrics\"]
				#type = \"prometheus\"
				"""
		}
	},

]
