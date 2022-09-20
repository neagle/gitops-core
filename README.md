# greymatter.io Core CUE

Enterprise-level CUE files for core greymatter.io mesh configurations.

## Prerequisites

- [CUE CLI](https://cuelang.org/docs/install/)

## Dependencies

This project makes use of git submodules for dependency management. The
<https://github.com/greymatter-io/greymatter-cue> submodule provides the
baseline greymatter.io Control Plane CUE schema.

## Getting Started

Fetch all necessary dependencies:

```sh
./scripts/bootstrap
```

> NOTE: If <https://github.com/greymatter-io/greymatter-cue> is updated, you
> can re-run this script to pull down the latest version.

## Verify CUE configurations

By running the following commands, you can do a quick sanity check to
ensure that the CUE evaluates correctly. If you receive any errors, you
will need to fix them before greymatter.io can successfully apply the  configurations to your mesh.

```sh
# evaluate control plane configurations
cue eval -c ./gm/outputs --out text -e mesh_configs_yaml
```

```sh
# evaluate Kubernetes manifests
cue eval -c ./k8s/outputs --out text -e k8s_manifests_yaml
```
