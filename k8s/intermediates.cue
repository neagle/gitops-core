package greymatter

import (
	corev1 "k8s.io/api/core/v1"
)

// Note that this container block needs to go in `containers`, and refers to a
// spire-socket volume that must be configured separately (see below)
#sidecar_container_block: {
	_Name: string
	_volume_mounts: [...]

	name:  "sidecar"
	image: mesh.spec.images.proxy
	ports: [...corev1.#ContainerPort] | *[
		{
			name:          "proxy"
			containerPort: defaults.ports.default_ingress
		},
		{
			name:          "metrics"
			containerPort: defaults.ports.metrics
		},
	]
	env: [
		{name: "XDS_CLUSTER", value:          _Name},
		{name: "ENVOY_ADMIN_LOG_PATH", value: "/dev/stdout"},
		{name: "PROXY_DYNAMIC", value:        "true"},
		{name: "XDS_ZONE", value:             mesh.spec.zone},
		{name: "XDS_HOST", value:             defaults.xds_host},
		{name: "XDS_PORT", value:             "50000"},
		if config.spire {
			{name: "SPIRE_PATH", value: "\(defaults.spire.socket_mount_path)/agent.sock"}
		},
	]
	resources: {
		limits: {
			cpu:    *"200m" | string
			memory: *"512Mi" | string
		}
		requests: {
			cpu:    *"50m" | string
			memory: *"128Mi" | string
		}

	}
	volumeMounts:    #sidecar_volume_mounts + _volume_mounts
	imagePullPolicy: defaults.image_pull_policy
}

#sidecar_volume_mounts: {
	if config.spire && defaults.spire.host_mount_socket {
		[{
			name:      "spire-socket"
			mountPath: defaults.spire.socket_mount_path
		}]
	}
	if defaults.edge.enable_tls {
		[{
			name:      "internal-tls-certs"
			mountPath: "/etc/proxy/tls/sidecar/"
		}]
	}
	[...]
}

#sidecar_volumes: {
	if config.spire && defaults.spire.host_mount_socket {
		[{
			name: "spire-socket"
			hostPath: {path: defaults.spire.socket_mount_path, type: "DirectoryOrCreate"}
		}]
	}
	if defaults.edge.enable_tls {
		[{
			name: "internal-tls-certs"
			secret: {defaultMode: 420, secretName: defaults.edge.secret_name}
		}]
	}
	[...]
}

#spire_permission_requests: {
	if config.spire && defaults.spire.host_mount_socket {
		hostPID: true
		// hostNetwork: true
		// dnsPolicy: "ClusterFirstWithHostNet"
	}
	...
}
