package greymatter

// Name needs to match the greymatter.io/cluster value in the Kubernetes deployment
let Name = "observables"
let ObservablesAppIngressName = "\(Name)_local"
let EgressToRedisName = "\(Name)_egress_to_redis"
let EgressToElasticSearchName = "\(Name)_egress_to_elasticsearch"

observables_config: [

	// HTTP ingress
	#domain & {domain_key: ObservablesAppIngressName},
	#listener & {
		listener_key:          ObservablesAppIngressName
		_spire_self:           Name
		_gm_observables_topic: Name
		_is_ingress:           true
	},
	#cluster & {cluster_key: ObservablesAppIngressName, _upstream_port: 5000},
	#route & {route_key:     ObservablesAppIngressName},

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
		ip:            "127.0.0.1"
		port:          defaults.ports.redis_ingress
		_tcp_upstream: defaults.redis_cluster_name
	},

	// egress -> elasticsearch
	#domain & {
		domain_key: EgressToElasticSearchName
		// don't change this, the app expects this port
		port: 9200
		custom_headers: [
			{
				key:   "Host"
				value: defaults.audits.elasticsearch_host
			},
		]
	},
	#cluster & {
		cluster_key:    EgressToElasticSearchName
		name:           "elasticsearch"
		require_tls:    true
		_upstream_host: defaults.audits.elasticsearch_host
		_upstream_port: defaults.audits.elasticsearch_port
	},
	// unused route must exist for the cluster to be registered with sidecar
	#route & {route_key: EgressToElasticSearchName},
	#listener & {
		listener_key: EgressToElasticSearchName
		// egress listeners are local-only
		ip: "127.0.0.1"
		// don't change this, the app expects this port
		port: 9200
	},

	// shared proxy object
	#proxy & {
		proxy_key: Name
		domain_keys: [ObservablesAppIngressName, EgressToRedisName, EgressToElasticSearchName]
		listener_keys: [ObservablesAppIngressName, EgressToRedisName, EgressToElasticSearchName]
	},

	// Config for greymatter.io edge ingress.
	#cluster & {
		cluster_key:  Name
		_spire_other: Name
	},
	#route & {
		domain_key: "edge"
		route_key:  Name
		route_match: {
			path: "/services/observables/"
		}
		redirects: [
			{
				from:          "^/services/observables$"
				to:            route_match.path
				redirect_type: "permanent"
			},
		]
		prefix_rewrite: "/"
	},

	// Config for edge ingress to support mesh-segmentation.
	#route & {
		domain_key:            defaults.edge.key
		route_key:             "\(Name)_edge_plus"
		_upstream_cluster_key: Name
		route_match: {
			path: "/services/observables/"
		}
		redirects: [
			{
				from:          "^/services/observables$"
				to:            route_match.path
				redirect_type: "permanent"
			},
		]
		prefix_rewrite: "/"
	},

	// Grey Matter Catalog service entry.
	#catalog_entry & {
		name:                      "Observables App"
		mesh_id:                   mesh.metadata.name
		service_id:                "observables"
		version:                   "0.0.1"
		description:               "A standalone dashboard visualizaing data collected from Grey Matter audits."
		api_endpoint:              "/services/observables"
		business_impact:           "critical"
		enable_instance_metrics:   true
		enable_historical_metrics: false
	},
]
