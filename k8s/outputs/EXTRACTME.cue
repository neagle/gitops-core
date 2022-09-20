// All k8s manifests objects for core componenents drawn together
// for simultaneous application

package greymatter

import "encoding/yaml"

_enable_jwtsecurity: *false | bool
if defaults.jwtsecurity != _|_ {
	_enable_jwtsecurity: defaults.jwtsecurity
}

jwt_security_manifests: jwt_security
// Spire-related manifests
spire_manifests: spire_namespace +
	spire_server +
	spire_agent
// Deploys the operator and optionally spire (so these manifests are in place before anything else)
operator_manifests: operator_namespace +
	operator_sts +
	operator_k8s +
	[ for x in openshift_privileged_scc if config.openshift {x}] +
	[ for x in openshift_spire_scc if config.openshift && config.spire {x}] +
	[ for x in spire_manifests if config.deploy_spire {x}] +
	[ for x in vector_permissions if config.enable_audits {x}]
// For development convenience, not otherwise used
all_but_operator_manifests: operator_namespace +
	operator_k8s +
	[ for x in spire_manifests if config.spire {x}]
// Deployed by the operator when you ask for a Mesh
k8s_manifests: controlensemble +
	catalog +
	redis +
	edge +
	dashboard +
	[ for x in prometheus if config.enable_historical_metrics && len(defaults.prometheus.external_host) == 0 {x}] +
	[ for x in prometheus_proxy if config.enable_historical_metrics && len(defaults.prometheus.external_host) > 0 {x}] +
	[ for x in openshift_spire if config.openshift && config.spire {x}] +
	[ for x in openshift_spire if config.openshift && config.spire {x}] +
	[ for x in observables if config.enable_audits {x}] +
	[ for x in vector if config.enable_audits {x}]

vector_manifests_yaml:      yaml.MarshalStream(vector)
observables_manifests_yaml: yaml.MarshalStream(observables)

prometheus_manifests: [ for x in prometheus if config.enable_historical_metrics && len(defaults.prometheus.external_host) == 0 {x}] +
	[ for x in prometheus_proxy if config.enable_historical_metrics && len(defaults.prometheus.external_host) > 0 {x}]

prometheus_scrape_rules: prometheus[len(prometheus)-1]
prometheus_rbac:         prometheus[1 : len(prometheus)-1]

// for CLI convenience,
// e.g. `cue eval -c ./k8s/outputs --out text -e k8s_manifests_yaml`
operator_manifests_yaml:         yaml.MarshalStream(operator_manifests)
all_but_operator_manifests_yaml: yaml.MarshalStream(all_but_operator_manifests)
spire_manifests_yaml:            yaml.MarshalStream(spire_manifests)
k8s_manifests_yaml:              yaml.MarshalStream(k8s_manifests)
prometheus_manifests_yaml:       yaml.MarshalStream(prometheus_manifests)
prometheus_scrape_rules_yaml:    yaml.Marshal(prometheus_scrape_rules)
prometheus_rbac_yaml:            yaml.MarshalStream(prometheus_rbac)

// TODO this was only necessary because I don't know how to pass _Name into #sidecar_container_block
// from Go. Then I decided to kill two birds with one stone and also put the sidecar_socket_volume in there.
// So for now, the way we get sidecar config for injected sidecars is to pull this structure and then
// separately apply the container and volumes to an intercepted Pod.
sidecar_container: {
	name: string | *"REPLACEME" // has a default just so literally everything is concrete by default

	container: #sidecar_container_block & {_Name: name}
	volumes:   #sidecar_volumes
}
