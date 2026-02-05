# Quick Start Guide

## Repository Setup ✅

Your GitOps repository is ready! Here's what we built:

```
container-gitops/
├── students/
│   └── week-01.yaml              # Students edit this file
├── manifests/
│   └── generated/                # Auto-generated K8s resources
├── scripts/
│   ├── validate-student.sh       # Validates submissions
│   └── generate-manifests.sh     # Generates K8s manifests
├── .github/workflows/
│   ├── validate-pr.yaml          # CI for PRs
│   └── generate-manifests.yaml   # Auto-generates on merge
└── README.md                     # Student-facing docs
```

## Next Steps

### 1. Test Locally (Optional)

Add a test student to verify everything works:

\`\`\`bash
cd ~/git/container-gitops

# Edit students/week-01.yaml and add a test entry
# Then generate manifests:
./scripts/generate-manifests.sh students/week-01.yaml

# Review generated files:
ls -la manifests/generated/

# Test apply (dry-run):
kubectl apply -k manifests/generated/ --dry-run=client
\`\`\`

### 2. Integrate with Your Cluster

Choose your GitOps tool:

#### Option A: Flux CD (Recommended)

Create this file in your gitops-homelab repo:

\`\`\`yaml
# ~/git/applied_knowledge/gitops-homelab/apps/base/container-course/student-gitops.yaml
---
apiVersion: source.toolkit.fluxcd.io/v1
kind: GitRepository
metadata:
  name: container-gitops
  namespace: flux-system
spec:
  interval: 1m0s
  url: https://github.com/ziyotek-edu/container-gitops
  ref:
    branch: main
---
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: container-course-students
  namespace: flux-system
spec:
  interval: 5m0s
  path: ./manifests/generated
  prune: true
  sourceRef:
    kind: GitRepository
    name: container-gitops
  targetNamespace: container-course-week01
\`\`\`

Then apply:
\`\`\`bash
kubectl apply -f ~/git/applied_knowledge/gitops-homelab/apps/base/container-course/student-gitops.yaml

# Watch it sync
flux get sources git container-gitops
flux get kustomizations container-course-students
\`\`\`

#### Option B: Manual Sync (Testing)

\`\`\`bash
cd ~/git/container-gitops
git pull
kubectl apply -k manifests/generated/
\`\`\`

### 3. Update Your Existing Infrastructure

You already have:
- ✅ Student router (nginx reverse proxy)
- ✅ Gallery deployment
- ✅ HTTPRoute configuration

Just need to update the gallery ConfigMap to be auto-generated:

**Remove** the static `gallery-nginx-config` from gitops-homelab (it will be generated from container-gitops)

### 4. Test the Full Workflow

1. **Add a test student** to `students/week-01.yaml`
2. **Commit and push** to main
3. **Watch GitHub Actions** generate manifests
4. **Watch GitOps** deploy to cluster
5. **Check the deployment**:
   \`\`\`bash
   kubectl get pods -n container-course-week01
   kubectl get svc -n container-course-week01
   \`\`\`

### 5. Point Students to the Repo

Share with students:
- **Repo URL:** https://github.com/ziyotek-edu/container-gitops
- **Instructions:** See [CONTRIBUTING.md](./CONTRIBUTING.md)
- **They need to:**
  1. Complete Lab 02 & 03
  2. Push container to GHCR (public)
  3. Submit PR adding their entry to `students/week-01.yaml`

## Monitoring

### Check Student Deployments
\`\`\`bash
# List all students
kubectl get deployments -n container-course-week01 -l app=student-app

# Check specific student
kubectl get pods -n container-course-week01 -l student=USERNAME

# View logs
kubectl logs -n container-course-week01 -l student=USERNAME -f
\`\`\`

### Check Gallery
\`\`\`bash
# Get student list from ConfigMap
kubectl get configmap gallery-nginx-config -n container-course-week01 -o jsonpath='{.data.default\.conf}' | grep -A 5 "api/students"

# Restart gallery to pick up changes
kubectl rollout restart deployment gallery -n container-course-week01
\`\`\`

### Force GitOps Sync
\`\`\`bash
# Flux
flux reconcile source git container-gitops
flux reconcile kustomization container-course-students

# Manual
cd ~/git/container-gitops && git pull && kubectl apply -k manifests/generated/
\`\`\`

## Troubleshooting

### CI Failing?
- Check GitHub Actions: https://github.com/ziyotek-edu/container-gitops/actions
- Review PR comments for validation errors

### Student Container Not Deploying?
1. Check if image is public: \`docker manifest inspect ghcr.io/user/repo:tag\`
2. Check deployment events: \`kubectl describe deployment student-USERNAME -n container-course-week01\`
3. Check pod logs: \`kubectl logs -l student=USERNAME -n container-course-week01\`

### Gallery Not Updating?
1. Ensure ConfigMap was regenerated
2. Restart gallery deployment
3. Check browser cache (hard refresh)

## URLs

Once deployed, students can access:
- **Their app:** https://container-course.YOUR_DOMAIN.com/students/USERNAME
- **Gallery:** https://container-course.YOUR_DOMAIN.com/gallery
- **Health check:** https://container-course.YOUR_DOMAIN.com/students/USERNAME/health

---

## Architecture Diagram

\`\`\`
Student                       GitHub                     Your Cluster
───────                      ────────                   ────────────

Push to GHCR ──────────┐
                       │
Fork Repo             │
Edit week-01.yaml     │
Submit PR ────────────┼────► CI Validates ───────┐
                      │       - YAML valid        │
                      │       - Image exists ◄────┘
                      │       - No duplicates
                      │
                      │      PR Merged
                      │          │
                      │          ▼
                      │      Generate Manifests
                      │          │
                      │          ▼
                      └────► GitOps Watches ────► Auto-Deploy
                                                      │
                                                      ▼
                                              Student Container
                                                   Running!
\`\`\`

Need help? Check [SETUP.md](./SETUP.md) for detailed instructions.
