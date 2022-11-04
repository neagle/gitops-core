// Grey Matter configuration for Prometheus's sidecar

package greymatter

let Name = "prometheus"
let LocalName = "\(Name)_local"
let EgressToRedisName = "\(Name)_egress_to_redis"

prometheus_config: [
	// sidecar -> prometheus
	#domain & {domain_key: LocalName, _force_https: true},
	#listener & {
		listener_key:          LocalName
		_spire_self:           Name
		_gm_observables_topic: Name
		_is_ingress:           true
	},
	#cluster & {
		cluster_key: LocalName
		if len(defaults.prometheus.external_host) > 0 {
			_upstream_host: defaults.prometheus.external_host
		}
		_upstream_port: [
				if defaults.prometheus.port != _|_ {defaults.prometheus.port},
				// 9090 is the default for when prometheus is deployed with greymatter
				9090,
		][0]

		if defaults.prometheus.tls.enabled {
			require_tls: true
			ssl_config: {
				cert_key_pairs: [
					{
						certificate_path: "/etc/proxy/tls/prometheus/server.crt"
						key_path:         "/etc/proxy/tls/prometheus/server.key"
					},
				]
			}
		}
	},

	#route & {route_key: LocalName},

	// egress -> redis
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
		ip:   "127.0.0.1"
		port: defaults.ports.redis_ingress
		// NB this points at a cluster name, not key
		_tcp_upstream: defaults.redis_cluster_name
	},

	// shared proxy object
	#proxy & {
		proxy_key: Name
		domain_keys: [LocalName, EgressToRedisName]
		listener_keys: [LocalName, EgressToRedisName]
	},

	// edge -> sidecar
	#cluster & {
		cluster_key:  Name
		_spire_other: Name
	},
	#route & {
		route_key:  Name
		domain_key: defaults.edge.key
		route_match: {
			path: "/services/prometheus/"
		}
		redirects: [
			{
				from:          "^/services/prometheus$"
				to:            route_match.path
				redirect_type: "permanent"
			},
		]
		prefix_rewrite: "/"
	},
]
