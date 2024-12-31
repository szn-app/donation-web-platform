

## Monorepo file organization: 
- `/manifest`: Kubernetes manifests for orchestration-specific configuration files. 
  - following base + overlays Kustomize folder structure https://kubernetes.io/docs/tasks/manage-kubernetes-objects/kustomization/#bases-and-overlays
- `/script` 

## Kubernetes HA for production
- 3 control plane nodes + 2 worker agent nodes should be the minimum