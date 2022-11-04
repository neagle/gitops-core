// All necessary Grey Matter configuration for an injected sidecar
// created during deployment assist.

package greymatter

#sidecar_config: {
	Name:              string | *defaults.edge.key // workaround for CUE's behavior with conflicting defaults
	Port:              int | *8080
	LocalName:         "\(Name)_local"
	EgressToRedisName: "\(Name)_egress_to_redis"

	objects: [
		// sidecar -> local service
		#domain & {domain_key: LocalName},
		#listener & {
			listener_key:          LocalName
			_spire_self:           Name
			_gm_observables_topic: Name
			_is_ingress:           true
		},
		#cluster & {cluster_key: LocalName, _upstream_port: Port},
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

		// proxy shared between local ingress and redis egress
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
			// destination cluster name is the same as route_key by default
			route_key: Name
			route_match: {
				path: "/services/\(Name)/"
			}
			redirects: [
				{
					from:          "^/services/\(Name)$"
					to:            route_match.path
					redirect_type: "permanent"
				},
			]
			prefix_rewrite: "/"
		},

		#catalog_entry & {
			name:                    Name
			mesh_id:                 mesh.metadata.name
			service_id:              Name
			api_endpoint:            "/services/\(Name)/"
			api_spec_endpoint:       "/services/\(Name)/"
			business_impact:         "low"
			enable_instance_metrics: true
		},
	]
}
