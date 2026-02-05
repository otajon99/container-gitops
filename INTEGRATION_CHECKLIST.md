# Integration Checklist

## ✅ What We Built

Repository: **https://github.com/ziyotek-edu/container-gitops**

### Components Created:

1. **Student Submission System**
   - `students/week-01.yaml` - Simple YAML file students edit
   - CONTRIBUTING.md - Step-by-step guide for students
   - PR-based workflow (students don't need K8s knowledge)

2. **CI/CD Pipeline**
   - `.github/workflows/validate-pr.yaml` - Validates PRs
   - `.github/workflows/generate-manifests.yaml` - Auto-generates manifests
   - `scripts/validate-student.sh` - Checks YAML, images, endpoints
   - `scripts/generate-manifests.sh` - Creates K8s resources

3. **Generated Kubernetes Resources** (auto-created per student)
   - Deployment (pulls from student's GHCR)
   - Service (student-{username}-svc)
   - Gallery ConfigMap (with student list)
   - Kustomization file

4. **Documentation**
   - README.md - Student-facing
   - SETUP.md - Instructor setup guide
   - QUICKSTART.md - TL;DR version
   - CONTRIBUTING.md - PR workflow

## 🔧 Integration with Your Cluster

### Option 1: Flux CD (Recommended for GitOps)

Add to your gitops-homelab repo:

\`\`\`bash
# Create the Flux resources
cat > ~/git/applied_knowledge/gitops-homelab/apps/base/container-course/student-gitops.yaml <<'YAML'
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
  healthChecks:
    - apiVersion: apps/v1
      kind: Deployment
      namespace: container-course-week01
      name: '*'
YAML

# Apply to cluster
kubectl apply -f ~/git/applied_knowledge/gitops-homelab/apps/base/container-course/student-gitops.yaml

# Verify
flux get sources git
flux get kustomizations
\`\`\`

### Option 2: Manual (for Testing)

\`\`\`bash
# Clone and apply
cd ~/git/container-gitops
git pull
kubectl apply -k manifests/generated/
\`\`\`

## 📝 TODO Before Students Submit

### 1. Update Lab 03 Instructions

Update `~/git/shart-cloud-gh/containers/container-course/week-01/labs/lab-03-registries/README.md`:

Change Part 4 to reference the new repo:
- Fork: `https://github.com/ziyotek-edu/container-gitops`
- Edit: `students/week-01.yaml` (not deployment repo)
- Link to CONTRIBUTING.md

### 2. Update HTTPRoute Domain

In your gitops-homelab, set the actual domain:

\`\`\`bash
# Edit this file:
vim ~/git/applied_knowledge/gitops-homelab/apps/base/container-course/httproute.yaml

# Change:
# hostnames:
#   - "container-course.YOUR_DOMAIN.com"
# to your actual domain
\`\`\`

### 3. Clean Up Old Static Gallery ConfigMap

The gallery ConfigMap is now auto-generated from container-gitops.

Remove static ConfigMap from gitops-homelab:
\`\`\`bash
cd ~/git/applied_knowledge/gitops-homelab/apps/base/container-course
# Remove or comment out gallery-nginx-config from gallery-service.yaml
# It will be replaced by the auto-generated one
\`\`\`

### 4. Test with a Dummy Student

\`\`\`bash
cd ~/git/container-gitops

# Edit students/week-01.yaml and add:
cat >> students/week-01.yaml <<'YAML'
  - name: "Test Student"
    github_username: "testuser"
    container_image: "nginx:alpine"
    student_endpoint: "/"
    health_endpoint: "/"
    port: 80
YAML

# Generate manifests
./scripts/generate-manifests.sh students/week-01.yaml

# Check generated files
ls -la manifests/generated/

# Apply to cluster
kubectl apply -k manifests/generated/

# Test
kubectl get pods -n container-course-week01 -l student=testuser
kubectl get svc -n container-course-week01 | grep testuser

# Access via router
curl http://student-router-service.container-course-week01.svc.cluster.local/students/testuser
\`\`\`

## 🎯 Student Workflow (Final)

1. Student completes Lab 02 (Flask app) & Lab 03 (Push to GHCR)
2. Student forks https://github.com/ziyotek-edu/container-gitops
3. Student edits `students/week-01.yaml`:
   \`\`\`yaml
   - name: "Jane Doe"
     github_username: "janedoe"
     container_image: "ghcr.io/janedoe/container-course-student:latest"
     student_endpoint: "/student"
     health_endpoint: "/health"
     port: 5000
   \`\`\`
4. Student creates PR
5. CI validates automatically
6. You merge PR
7. GitHub Actions generates manifests and commits
8. Flux/GitOps syncs to cluster
9. Student's container deploys automatically
10. Student sees their app at `/students/janedoe`

## 🔍 Verification Commands

\`\`\`bash
# Check Flux source
flux get sources git container-gitops

# Check Flux kustomization
flux get kustomizations container-course-students

# Force reconcile
flux reconcile source git container-gitops
flux reconcile kustomization container-course-students

# Check deployments
kubectl get deployments -n container-course-week01 -l app=student-app

# Check services
kubectl get svc -n container-course-week01 | grep student

# Check gallery ConfigMap
kubectl get configmap gallery-nginx-config -n container-course-week01 -o yaml

# Test student router
kubectl port-forward -n container-course-week01 svc/student-router-service 8080:80
# Then: curl http://localhost:8080/students/USERNAME
\`\`\`

## 📊 Monitoring

\`\`\`bash
# Watch all student pods
kubectl get pods -n container-course-week01 -l app=student-app -w

# Watch GitOps sync
flux logs --follow --kind=Kustomization --name=container-course-students

# Check student deployment status
kubectl get deployment -n container-course-week01 student-USERNAME -o jsonpath='{.status.conditions[?(@.type=="Available")].status}'
\`\`\`

## 🐛 Troubleshooting

| Issue | Check | Fix |
|-------|-------|-----|
| Student container not deploying | Image accessibility | \`docker manifest inspect IMAGE\` |
| Gallery not updating | ConfigMap content | Restart gallery pod |
| GitOps not syncing | Flux status | \`flux reconcile...\` |
| 404 on student route | Service name | Must be \`student-{username}-svc\` |

## ✨ Next Steps

- [ ] Set up Flux CD integration (or test manually)
- [ ] Test with dummy student
- [ ] Update Lab 03 instructions
- [ ] Update HTTPRoute domain
- [ ] Remove static gallery ConfigMap
- [ ] Announce to students with repo URL
- [ ] Monitor first few PR submissions

