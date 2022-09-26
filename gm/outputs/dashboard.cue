// Grey Matter configuration for Dashboard's sidecar

package greymatter

let Name = "dashboard"
let LocalName = "dashboard_local"
let EgressToRedisName = "\(Name)_egress_to_redis"

dashboard_config: [
	// sidecar -> dashboard
	#domain & {domain_key: LocalName},
	#listener & {
		listener_key:          LocalName
		_spire_self:           Name
		_gm_observables_topic: Name
		_is_ingress:           true
	},
	#cluster & {cluster_key: LocalName, _upstream_port: 1337},
	#route & {route_key:     LocalName},

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
		domain_key: defaults.edge.key
		route_match: {
			path:       "/dashboard"
		}
		route_key: Name
	},

]
