// All Catalog Service entries

package greymatter

import (
	"strings"
)

prometheusName: [
		if len(defaults.prometheus.external_host) > 0 {"Grey Matter Prometheus Proxy"},
		"Grey Matter Prometheus",
][0]

catalog_entries: [
	#catalog_entry & {
		name:                      "Grey Matter Edge"
		mesh_id:                   mesh.metadata.name
		service_id:                defaults.edge.key
		version:                   strings.Split(mesh.spec.images.proxy, ":")[1]
		description:               "Handles north/south traffic flowing through the mesh."
		api_endpoint:              "/"
		business_impact:           "critical"
		enable_instance_metrics:   true
		enable_historical_metrics: config.enable_historical_metrics
	},
	#catalog_entry & {
		name:                      "Grey Matter Control"
		mesh_id:                   mesh.metadata.name
		service_id:                "controlensemble"
		version:                   strings.Split(mesh.spec.images.control_api, ":")[1]
		description:               "Manages the configuration of the Grey Matter data plane."
		api_endpoint:              "/services/control-api/"
		business_impact:           "critical"
		api_spec_endpoint:         "/services/control-api/"
		enable_instance_metrics:   true
		enable_historical_metrics: config.enable_historical_metrics
	},
	#catalog_entry & {
		name:                      "Grey Matter Catalog"
		mesh_id:                   mesh.metadata.name
		service_id:                "catalog"
		version:                   strings.Split(mesh.spec.images.catalog, ":")[1]
		description:               "Interfaces with the control plane to expose the current state of the mesh."
		api_endpoint:              "/services/catalog/"
		api_spec_endpoint:         "/services/catalog/"
		business_impact:           "high"
		enable_instance_metrics:   true
		enable_historical_metrics: config.enable_historical_metrics
	},
	#catalog_entry & {
		name:                      "Grey Matter Dashboard"
		mesh_id:                   mesh.metadata.name
		service_id:                "dashboard"
		version:                   strings.Split(mesh.spec.images.dashboard, ":")[1]
		description:               "A user dashboard that paints a high-level picture of the mesh."
		business_impact:           "high"
		enable_instance_metrics:   true
		enable_historical_metrics: config.enable_historical_metrics
	},
	if config.enable_historical_metrics {
		#catalog_entry & {
			name:                      prometheusName
			mesh_id:                   mesh.metadata.name
			service_id:                "prometheus"
			version:                   strings.Split(mesh.spec.images.prometheus, ":")[1]
			description:               "Prometheus TSDB for collecting and querying historical metrics."
			business_impact:           "high"
			api_endpoint:              "/services/prometheus/graph"
			enable_instance_metrics:   true
			enable_historical_metrics: config.enable_historical_metrics
		}
	},
]
