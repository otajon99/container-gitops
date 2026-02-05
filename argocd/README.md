# ArgoCD Integration

This directory contains the ArgoCD Application manifest for automatically deploying student containers.

## Quick Deploy

Apply the ArgoCD Application to your cluster:

```bash
kubectl apply -f argocd/application.yaml
```

## What it does

The ArgoCD Application:
- Watches the `manifests/generated/` directory in this repo
- Automatically syncs changes when students submit PRs (after CI generates manifests)
- Creates the `container-course-week01` namespace if it doesn't exist
- Prunes removed resources automatically
- Self-heals if manifests drift from desired state

## Verify Deployment

```bash
# Check Application status
kubectl get application container-course-students -n argocd

# Watch sync progress
kubectl get application container-course-students -n argocd -w

# View in ArgoCD UI
# Navigate to: Applications > container-course-students
```

## Integration with gitops-homelab

If you're using a gitops-homelab repo, you can reference this Application:

```yaml
# In your gitops-homelab repo
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: container-course-students
  namespace: argocd
spec:
  source:
    repoURL: https://github.com/ziyotek-edu/container-gitops
    targetRevision: main
    path: argocd
  destination:
    server: https://kubernetes.default.svc
    namespace: argocd
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

This creates an "App of Apps" pattern where your homelab manages the student course Application.
