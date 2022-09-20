// k8s manifests for Observables App

package greymatter

import (
	appsv1 "k8s.io/api/apps/v1"
)

let Name = "observables"

observables: [
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
						#sidecar_container_block & {_Name: Name},
						{
							name:            Name
							image:           defaults.images.observables
							imagePullPolicy: defaults.image_pull_policy
							ports: [{
								containerPort: 5000
							}]
							env: [{
								name:  "BASE_PATH"
								value: "/services/observables"
							}, {
								name:  "ES_INDEX"
								value: "gm-audits*"
							}, {
								name:  "ES_EDGE_TOPIC"
								value: "edge"
							}, {
								name:  "TARGET_PRODUCT"
								value: "gm"
							}, {
								name:  "ES_USER"
								value: "elastic"
							}, {
								name: "ES_PASSWORD"
								valueFrom: {
									secretKeyRef: {
										name: "elasticsearch-password"
										key:  "password"
									}
								}
							}]
							resources: {
								limits: {
									cpu:    "1"
									memory: "2Gi"
								}
								requests: {
									cpu:    "500m"
									memory: "1Gi"
								}
							}
						},
					]
					volumes: #sidecar_volumes
					imagePullSecrets: [{
						name: "gm-docker-secret"
					}]
				}
			}
		}
	},
]
