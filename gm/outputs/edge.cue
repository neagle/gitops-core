// Grey Matter configuration for Edge

package greymatter

let EgressToRedisName = "\(defaults.edge.key)_egress_to_redis"

// Uncomment the below line for use with a remote JWKS provider (in this case, Keycloak)
let EdgeToKeycloakName = defaults.edge.oidc.jwt_authn_provider.keycloak.remote_jwks.http_uri.cluster

edge_config: [
	#domain & {
		domain_key:   defaults.edge.key
		_force_https: defaults.edge.enable_tls
	},
	#listener & {
		listener_key:                defaults.edge.key
		_gm_observables_topic:       defaults.edge.key
		_is_ingress:                 true
		_enable_oidc_authentication: true
		_enable_rbac:                false
		_enable_fault_injection:     false
		_enable_ext_authz:           false
		_oidc_endpoint:              defaults.edge.oidc.endpoint
		_oidc_service_url:           "https://\(defaults.edge.oidc.domain):\(defaults.ports.edge_ingress)"
		_oidc_provider:              "\(defaults.edge.oidc.endpoint)/auth/realms/\(defaults.edge.oidc.realm)"
		_oidc_client_id:             defaults.edge.oidc.client_id
		_oidc_client_secret:         defaults.edge.oidc.client_secret
		_oidc_cookie_domain:         defaults.edge.oidc.domain
		_oidc_realm:                 defaults.edge.oidc.realm
	},
	// This cluster must exist (though it never receives traffic)
	// so that Catalog will be able to look-up edge instances
	#cluster & {cluster_key: defaults.edge.key},

	// egress -> redis
	#domain & {domain_key: EgressToRedisName, port: defaults.ports.redis_ingress},
	#cluster & {
		cluster_key:  EgressToRedisName
		name:         defaults.redis_cluster_name
		_spire_self:  defaults.edge.key
		_spire_other: defaults.redis_cluster_name
	},
	#route & {route_key: EgressToRedisName},
	#listener & {
		listener_key: EgressToRedisName
		// egress listeners are local-only
		ip:            "127.0.0.1"
		port:          defaults.ports.redis_ingress
		_tcp_upstream: defaults.redis_cluster_name
	},

	#proxy & {
		proxy_key: defaults.edge.key
		domain_keys: [defaults.edge.key, EgressToRedisName, EdgeToKeycloakName]
		listener_keys: [defaults.edge.key, EgressToRedisName, EdgeToKeycloakName]
	}

	// egress -> Keycloak for OIDC/JWT Authentication (only necessary with remote JWKS provider)
	// NB: You need to add the EdgeToKeycloakName key to the domain_keys and listener_keys 
	// in the #proxy above for the cluster to be discoverable by Envoy
	#cluster & {
	 cluster_key:    EdgeToKeycloakName
	 _upstream_host: defaults.edge.oidc.endpoint_host
	 _upstream_port: defaults.edge.oidc.endpoint_port
	 ssl_config: {
	  protocols: ["TLSv1_2"]
	  sni: defaults.edge.oidc.endpoint_host
	 }
	 require_tls: true
	},
	#route & {route_key:   EdgeToKeycloakName},
	#domain & {domain_key: EdgeToKeycloakName, port: defaults.edge.oidc.endpoint_port},
	#listener & {
	 listener_key: EdgeToKeycloakName
	 port:         defaults.edge.oidc.endpoint_port
	},
]
