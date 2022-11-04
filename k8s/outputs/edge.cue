package greymatter

import (
	appsv1 "k8s.io/api/apps/v1"
	corev1 "k8s.io/api/core/v1"
)

edge: [
	appsv1.#Deployment & {
		apiVersion: "apps/v1"
		kind:       "Deployment"
		metadata: {
			name:      defaults.edge.key
			namespace: mesh.spec.install_namespace
		}
		spec: {
			selector: {
				matchLabels: {"greymatter.io/cluster": defaults.edge.key}
			}
			template: {
				metadata: {
					labels: {
						"greymatter.io/cluster":  defaults.edge.key
						"greymatter.io/workload": "\(config.operator_namespace).\(mesh.metadata.name).\(defaults.edge.key)"
					}
				}
				spec: #spire_permission_requests & {
					containers: [
						#sidecar_container_block & {
							_Name: defaults.edge.key
							_volume_mounts: [
								if defaults.edge.enable_tls == true {
									{
										name:      "tls-certs"
										mountPath: "/etc/proxy/tls/edge"
									}
								},
							]
							resources: {
								limits: {cpu: "200m", memory: "200Mi"}
								requests: {cpu: "100m", memory: "128Mi"}
							}
						},
					]
					volumes: #sidecar_volumes + [
							if defaults.edge.enable_tls == true {
							{
								name: "tls-certs"
								secret: {
									defaultMode: 420
									secretName:  defaults.edge.secret_name
								}
							}
						},
					]
					imagePullSecrets: [{name: defaults.image_pull_secret_name}]
				}
			}
		}
	},

	corev1.#Service & {
		apiVersion: "v1"
		kind:       "Service"
		metadata: {
			name:      defaults.edge.key
			namespace: mesh.spec.install_namespace
		}
		spec: {
			selector: "greymatter.io/cluster": defaults.edge.key
			type: "LoadBalancer"
			ports: [{
				name:       "ingress"
				port:       defaults.ports.edge_ingress
				targetPort: defaults.ports.edge_ingress
			}]
		}
	},
]
