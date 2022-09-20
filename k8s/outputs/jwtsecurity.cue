// Manifests for the jwt_security pod

package greymatter

import (
	appsv1 "k8s.io/api/apps/v1"
)

let Name = "jwt-security"
jwt_security: [
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
							name:  Name
							image: mesh.spec.images.jwt_security
							ports: [{
								name:          "http"
								containerPort: 8080
							}]
							env: [
								// This needs to be present in order to disable redis caching. 
								{
									name:  "REDIS_HOST"
									value: ""
								},
								{
									name:  "HTTP_PORT"
									value: "8080"
								},
								{
									name:  "ENABLE_TLS"
									value: "false"
								},
								{
									name: "JWT_API_KEY"
									valueFrom: {
										secretKeyRef: {
											name: "jwt-api-key"
											key:  "value"
										}
									}
								},
								{
									name: "PRIVATE_KEY"
									valueFrom: {
										secretKeyRef: {
											name: "jwt-private-key"
											key:  "value"
										}
									}
								},
								{
									name: "USERS_JSON"
									valueFrom: {
										secretKeyRef: {
											name: "jwt-users-json"
											key:  "value"
										}
									}
								},
							]
							resources: {
								requests: {cpu: "50m", memory: "128Mi"}
							}
							imagePullPolicy: defaults.image_pull_policy
						},
					]
					volumes: #sidecar_volumes
					imagePullSecrets: [{name: defaults.image_pull_secret_name}]
				}
			}
		}
	},
]
