// Grey Matter configuration for jwt_security's sidecar

package greymatter

let Name = "jwt-security"
let JWTsecurityIngressName = "\(Name)_local"
let EgressToRedisName = "\(Name)_egress_to_redis"

jwtsecurity_config: [

	// jwtsecurity HTTP ingress
	#domain & {domain_key: JWTsecurityIngressName},
	#listener & {
		listener_key:          JWTsecurityIngressName
		_spire_self:           Name
		_gm_observables_topic: Name
		_is_ingress:           true
	},
	#cluster & {cluster_key: JWTsecurityIngressName, _upstream_port: 8080},
	#route & {route_key:     JWTsecurityIngressName},

	// egress -> Metrics redis
	#domain & {domain_key: EgressToRedisName, port: defaults.ports.redis_ingress},
	#cluster & {
		cluster_key:  EgressToRedisName
		name:         defaults.redis_cluster_name
		_spire_self:  Name
		_spire_other: defaults.redis_cluster_name
	},
	// unused route must exist for the cluster to be registered with sidecar
	#route & {route_key: EgressToRedisName},
	#listener & {
		listener_key: EgressToRedisName
		// egress listeners are local-only
		ip:            "127.0.0.1"
		port:          defaults.ports.redis_ingress
		_tcp_upstream: defaults.redis_cluster_name
	},

	// shared proxy object
	#proxy & {
		proxy_key: Name
		domain_keys: [JWTsecurityIngressName, EgressToRedisName]
		listener_keys: [JWTsecurityIngressName, EgressToRedisName]
	},

	// Edge config for jwtsecurity ingress
	#cluster & {
		cluster_key:  Name
		_spire_other: Name
	},
	#route & {
		domain_key: defaults.edge.key
		route_key:  Name
		route_match: {
			path: "/services/jwtsecurity/"
		}
		redirects: [
			{
				from:          "^/services/jwtsecurity$"
				to:            route_match.path
				redirect_type: "permanent"
			},
		]
		prefix_rewrite: "/"
	},

]
