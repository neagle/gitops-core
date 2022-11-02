package greymatter

import (
	corev1 "k8s.io/api/core/v1"
	"github.com/greymatter-io/common/api/meshv1"
)

config: {
	// Flags
	// use Spire-based mTLS (ours or another)
	spire: bool | *false @tag(spire,type=bool)
	// deploy our own server and agent
	deploy_spire: bool | *spire @tag(use_spire,type=bool)
	// if we're deploying into OpenShift, request extra permissions
	openshift: bool | *false @tag(openshift,type=bool)
	// deploy and configure Prometheus for historical metrics in the Dashboard
	enable_historical_metrics: bool | *false @tag(enable_historical_metrics,type=bool)
	// deploy and configure audit pipeline for observability telemetry
	enable_audits: bool | *true @tag(enable_audits,type=bool)
	// whether to automatically copy the image pull secret to watched namespaces for sidecar injection
	auto_copy_image_pull_secret: bool | *true @tag(auto_copy_image_pull_secret, type=bool)
	// namespace the operator will deploy into
	operator_namespace: string | *"gm-operator" @tag(operator_namespace, type=string)

	// for a hypothetical future where we want to mount specific certificates for operator webhooks, etc.
	generate_webhook_certs: bool | *true        @tag(generate_webhook_certs,type=bool)
	cluster_ingress_name:   string | *"cluster" // For OpenShift deployments, this is used to look up the configured ingress domain

	// currently just controls k8s/outputs/operator.cue for debugging
	debug: bool | *false @tag(debug,type=bool)
	// test=true turns off GitOps, telling the operator to use the baked-in CUE
	test: bool | *false @tag(test,type=bool) // currently just turns off GitOps so CI integration tests can manipulate directly
}

mesh: meshv1.#Mesh & {
	metadata: {
		name: string | *"greymatter-mesh"
	}
	spec: {
		install_namespace: string | *"greymatter"
		watch_namespaces:  [...string] | *["default", "plus", "examples"]
		zone:              string | *"default-zone"
		images: {
			proxy:        string | *"quay.io/greymatterio/gm-proxy:1.7.1"
			catalog:      string | *"quay.io/greymatterio/gm-catalog:3.0.5"
			dashboard:    string | *"quay.io/greymatterio/gm-dashboard:rel-6.0.2"
			control:      string | *"quay.io/greymatterio/gm-control:1.7.3"
			control_api:  string | *"quay.io/greymatterio/gm-control-api:1.7.3"
			redis:        string | *"redis:latest"
			prometheus:   string | *"prom/prometheus:v2.36.2"
			jwt_security: string | *"quay.io/greymatterio/gm-jwt-security:1.3.1"
		}
	}
}

defaults: {
	image_pull_secret_name: string | *"gm-docker-secret"
	image_pull_policy:      corev1.#enumPullPolicy | *corev1.#PullAlways
	xds_host:               "controlensemble.\(mesh.spec.install_namespace).svc.cluster.local"
	sidecar_list:           [...string] | *["dashboard", "catalog", "controlensemble", "edge", "redis", "prometheus", "jwtsecurity", "observables"]
	proxy_port_name:        "proxy" // the name of the ingress port for sidecars - used by service discovery
	redis_cluster_name:     "redis"
	redis_host:             "\(redis_cluster_name).\(mesh.spec.install_namespace).svc.cluster.local"
	redis_port:             6379
	redis_db:               0
	redis_username:         ""
	redis_password:         ""
	// key names for applied-state backups to Redis - they only need to be unique.
	gitops_state_key_gm:      "\(config.operator_namespace).gmHashes"
	gitops_state_key_k8s:     "\(config.operator_namespace).k8sHashes"
	gitops_state_key_sidecar: "\(config.operator_namespace).sidecarHashes"

	ports: {
		default_ingress: 10808
		edge_ingress:    defaults.ports.default_ingress
		redis_ingress:   10910
		metrics:         8081
	}

	images: {
		operator:    string | *"quay.io/greymatterio/operator:0.10.0" @tag(operator_image)
		vector:      string | *"timberio/vector:0.22.0-debian"
		observables: string | *"quay.io/greymatterio/observables:1.1.3"
	}

	// The external_host field instructs greymatter to install Prometheus or
	// uses an external one. If enable_historical_metrics is true and external_host
	// is empty, then greymatter will install Prometheus into the greymatter
	// namespace. If enable_historical_metrics is true and external_host has a
	// value, greymatter will not install Prometheus into the greymatter namespace
	// and will connect to the external Prometheus via a sidecar
	// (e.g. external_host: prometheus.metrics.svc).
	prometheus: {
		external_host: ""
		port:          9090
		tls: {
			enabled:     false
			cert_secret: "gm-prometheus-certs"
		}
	}

	// audits configuration applies to greymatter's observability pipeline and are
	// used when config.enable_audits is true.  
	audits: {
		// index determines the index ID in Elasticsearch. The default naming convention
		// will generate a new index each month. The index configuration can be changed
		// to create more or less indexes depending on your storage and performance requirements.
		index: "gm-audits-%Y-%m"
		// elasticsearch_host can be an IP address or DNS hostname to your Elasticsearch instace.
		elasticsearch_host: "ce2369d9f49c4d0aad061f6e2fca7a2d.centralus.azure.elastic-cloud.com"
		// elasticsearch_port is the port of your Elasticsearch instance.
		elasticsearch_port: 443
		// elasticsearch_endpoint is the full endpoint containing protocol, host, and port
		// of your Elasticsearch instance. This is used by Vector to sink audit data
		// with Elasticsearch.
		elasticsearch_endpoint: "https://\(elasticsearch_host):\(elasticsearch_port)"
	}

	edge: {
		key:        "edge"
		enable_tls: false
		oidc: {
			endpoint_host: "keycloak.greymatter.services"
			endpoint_port: 8553
			endpoint:      "https://\(endpoint_host):\(endpoint_port)"
			domain:        "104.45.186.7"
			client_id:     "edge"
			client_secret: "3a4522e4-6ed0-4ba6-9135-13f0027c4b47"
			realm:         "greymatter"
			jwt_authn_provider: {
				keycloak: {
					issuer: "\(endpoint)/auth/realms/\(realm)"
					audiences: ["edge"]
					local_jwks: {
						inline_string: #"""
						{
							"keys": [
									{
										"kid": "-wqLIfvKPA-nzfizy97BzXW-ZNmNEL5vuNA7IteQqRw",
										"kty": "RSA",
										"alg": "RS256",
										"use": "enc",
										"n": "m-qEAv-dqehkBnqMrSn-feu7g_C3hZkTlPB1xpoghacR1MidBYuAp82pCwG0qhG0NEsT76nit4pS3V9gMTXg331kKJtELewDWbyim1v3oU5Tsn2uQJ8tu8FqY7DnnUoZsoxlqRn3mVYDOg7I5qej2nqu8hBPPzWauqNt6YmwUMnkkdX7YYe-LZTgVhhFzwx8inNuGLFDE93L6f-2GnyjLubtMy7XZ32FC9GIWzZqy8KYgDGKkcPt69OsJPUgmaMjBx_k4ZXrUYPKGtCTZJBqK_awXAWDXKub-c3zI2sz8p08EwvMsj5E9CnNr7vR0nukqMvW66LJJoglqJMYTnqN5Q",
										"e": "AQAB",
										"x5c": [
											"MIICozCCAYsCBgF7MffL8jANBgkqhkiG9w0BAQsFADAVMRMwEQYDVQQDDApncmV5bWF0dGVyMB4XDTIxMDgxMDIxMjcwOFoXDTMxMDgxMDIxMjg0OFowFTETMBEGA1UEAwwKZ3JleW1hdHRlcjCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBAJvqhAL/nanoZAZ6jK0p/n3ru4Pwt4WZE5TwdcaaIIWnEdTInQWLgKfNqQsBtKoRtDRLE++p4reKUt1fYDE14N99ZCibRC3sA1m8optb96FOU7J9rkCfLbvBamOw551KGbKMZakZ95lWAzoOyOano9p6rvIQTz81mrqjbemJsFDJ5JHV+2GHvi2U4FYYRc8MfIpzbhixQxPdy+n/thp8oy7m7TMu12d9hQvRiFs2asvCmIAxipHD7evTrCT1IJmjIwcf5OGV61GDyhrQk2SQaiv2sFwFg1yrm/nN8yNrM/KdPBMLzLI+RPQpza+70dJ7pKjL1uuiySaIJaiTGE56jeUCAwEAATANBgkqhkiG9w0BAQsFAAOCAQEAmxHyFXutsgeNHpzjYEWnsLlWuEGENU7uy3OP5Yg44Bck5eSMImVczLq1EL/tyOsH0omEL5i3re0g09Tdr4fM2bslQnekWDKQhl8IuKrnzNm5AmtDhItgXF6jjeEV4YiNfKxERFOKQj07lHyd/a02DZAoVYF5FkDYG8rFhl8U5aRLUKahPJ8XKLANb5UJ+Jw7O/HbE7dEqopd/8JltTTpWxmE7Uwb/C6R5eUUi2h9ctH+XT6PRWtGYvGGqaI42ED6Wg107GpQgG9/Pc/6P5/7JaIJoR0gSnh6ZMCWYvczfQD8Nz3GoN+2vKzL7kFTYxAvMSO9FdyRoOW1QXU2zRdz9A=="
										],
										"x5t": "h4gM4aFODnGQqHcQnpgfnVS8Sn4",
										"x5t#S256": "34ikv_gX-UF_3IooQlRQs0CDg9nxnFAW3ccqt1ce8Mo"
									},
									{
										"kid": "qvyQDIVLm8HSawo-QR_EWgzVNkjjzUM7yVegEq_vg3o",
										"kty": "RSA",
										"alg": "RS256",
										"use": "sig",
										"n": "ofgOqqkaop-9RGXiQ3NYi6GVqciApRBy7kwxgrRS28Evv-c0egiqxBya3TBrkuYbXEMwtYQK6RVrpiHcMbTMmWUCc7e06bsDHINQiZ-8lzSkchcyvHrtM0yT9R6XeWOZ3TFE1hGLbNgOss3CoXyuZCNY2nk9ijGT2hgPVp1PZTWsW7MsJ6ESUSNVA5-PrgtdxECRmowjjx05iaP_nLOnEcd7hOyhmuDcPRuOJ3fku3tSPBLlmX8p-0qxBM45EkUjL3uhV2fDaGF-IdHEKiwXjcw4_m30YW1IEOp8SEJuaHC_ZuhfiuQIgarXEVYNpDNGtBDf7rrqaieQIT5Gfv1bRQ",
										"e": "AQAB",
										"x5c": [
											"MIICozCCAYsCBgF7MffLrDANBgkqhkiG9w0BAQsFADAVMRMwEQYDVQQDDApncmV5bWF0dGVyMB4XDTIxMDgxMDIxMjcwOFoXDTMxMDgxMDIxMjg0OFowFTETMBEGA1UEAwwKZ3JleW1hdHRlcjCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBAKH4DqqpGqKfvURl4kNzWIuhlanIgKUQcu5MMYK0UtvBL7/nNHoIqsQcmt0wa5LmG1xDMLWECukVa6Yh3DG0zJllAnO3tOm7AxyDUImfvJc0pHIXMrx67TNMk/Uel3ljmd0xRNYRi2zYDrLNwqF8rmQjWNp5PYoxk9oYD1adT2U1rFuzLCehElEjVQOfj64LXcRAkZqMI48dOYmj/5yzpxHHe4TsoZrg3D0bjid35Lt7UjwS5Zl/KftKsQTOORJFIy97oVdnw2hhfiHRxCosF43MOP5t9GFtSBDqfEhCbmhwv2boX4rkCIGq1xFWDaQzRrQQ3+666monkCE+Rn79W0UCAwEAATANBgkqhkiG9w0BAQsFAAOCAQEAoIuSxzI3lvbxSZaIZlPOtMi4lWm7Y4lbXaDVGsIUn0oqVMDYGU7+qVwcTXrXBKm93IliA5QKg89mtvAFcSp9pD7U9ZPYRy0kdLFVDsyQZpqWq991uEamPa5A2mJrIbLJphQgE/OmKUGNAZ8EtuMTdCCanECsAUrquTV/3mjF+AFVOvn3fsgd67sk9TLnpkZRNpeToY7TTqkP1br1UQOspw4AaVkCZjn8Mu3OzQ9Oo0OiROAD44QRp9Ll9I0leSI8npIPR/Q1jlfmimn22B00d4i5SwgiqciMZAWNmOHWXqq1qidO15L+4V7yCIuLPXjyWHDEFqolOdm1sh2Qv7spdg=="
										],
										"x5t": "qgqM1xQkNt_DGOtVuIHhprB1Ogs",
										"x5t#S256": "54pnvk_g1Hl3G15KeaXiyXe0mRQtqHtclwvBqIUTq2A"
									}
								]
							}
						"""#
					}
					// If you want to use a remote JWKS provider, comment out local_jwks above, and
					// uncomment the below remote_jwks configuration. There are coinciding configurations
					// in ./gm/outputs/edge.cue that you will also need to uncomment.
					// remote_jwks: {
					//  http_uri: {
					//   uri:     "\(endpoint)/auth/realms/\(realm)/protocol/openid-connect/certs"
					//   cluster: "edge_to_keycloak" // this key should be unique across the mesh
					//  }
					// }
				}
			}
		}
	} // edge

	spire: {
		// Namespace of the Spire server
		namespace: "spire"
		// Trust domain must match what's configured at the server
		trust_domain: "greymatter.io"
		// The mount path of the spire socket for communication with the agent
		socket_mount_path: "/run/spire/socket"
		// When config.deploy_spire=true, we inject a secret. This sets the name of that secret
		ca_secret_name: "server-ca"
		// should we request a host mount for the socket, or normal volume mount? If true, also requests hostPID permission
		host_mount_socket: true
	}

} // defaults
