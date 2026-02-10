#!/bin/bash
set -e

STUDENT_FILE="$1"
DRY_RUN="${2:-false}"

if [ ! -f "$STUDENT_FILE" ]; then
    echo "❌ Student file not found: $STUDENT_FILE"
    exit 1
fi

OUTPUT_DIR="manifests/generated"
mkdir -p "$OUTPUT_DIR"

echo "=== Generating Kubernetes Manifests ==="
echo "Input: $STUDENT_FILE"
echo "Output: $OUTPUT_DIR"
echo ""

# Extract namespace
NAMESPACE=$(yq eval '.metadata.namespace' "$STUDENT_FILE")
WEEK=$(yq eval '.metadata.week' "$STUDENT_FILE")

# Clear previous generated files
if [ "$DRY_RUN" != "dry-run" ]; then
    rm -f "$OUTPUT_DIR"/*.yaml
fi

# Generate namespace
cat > "$OUTPUT_DIR/namespace.yaml" <<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: $NAMESPACE
EOF

echo "✅ Generated namespace.yaml"

# Extract students
STUDENT_COUNT=$(yq eval '.students | length' "$STUDENT_FILE")
STUDENT_LIST="[]"

for i in $(seq 0 $((STUDENT_COUNT - 1))); do
    NAME=$(yq eval ".students[$i].name" "$STUDENT_FILE")
    USERNAME=$(yq eval ".students[$i].github_username" "$STUDENT_FILE")
    IMAGE=$(yq eval ".students[$i].container_image" "$STUDENT_FILE")
    PORT=$(yq eval ".students[$i].port // 5000" "$STUDENT_FILE")
    HEALTH_ENDPOINT=$(yq eval ".students[$i].health_endpoint // \"/health\"" "$STUDENT_FILE")

    # Skip null entries
    if [ "$NAME" == "null" ] || [ "$USERNAME" == "null" ]; then
        continue
    fi

    # Convert username to lowercase for Kubernetes resource names
    USERNAME_LOWER="${USERNAME,,}"

    echo "Generating resources for: $USERNAME"

    # Add to student list for gallery (compact JSON)
    STUDENT_LIST=$(echo "$STUDENT_LIST" | jq -c --arg name "$NAME" --arg user "$USERNAME" --arg health "$HEALTH_ENDPOINT" '. += [{"name": $name, "github_username": $user, "health_endpoint": $health}]')

    # Generate Deployment
    cat > "$OUTPUT_DIR/student-${USERNAME_LOWER}-deployment.yaml" <<EOF
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: student-${USERNAME_LOWER}
  namespace: ${NAMESPACE}
  labels:
    app: student-app
    student: ${USERNAME_LOWER}
    week: "${WEEK}"
spec:
  replicas: 1
  selector:
    matchLabels:
      app: student-app
      student: ${USERNAME_LOWER}
  template:
    metadata:
      labels:
        app: student-app
        student: ${USERNAME_LOWER}
    spec:
      containers:
      - name: student-app
        image: ${IMAGE}
        ports:
        - containerPort: ${PORT}
          name: http
        env:
        - name: STUDENT_NAME
          value: "${NAME}"
        - name: GITHUB_USERNAME
          value: "${USERNAME}"
        resources:
          requests:
            memory: "64Mi"
            cpu: "50m"
          limits:
            memory: "256Mi"
            cpu: "200m"
        livenessProbe:
          httpGet:
            path: ${HEALTH_ENDPOINT}
            port: ${PORT}
          initialDelaySeconds: 10
          periodSeconds: 30
        readinessProbe:
          httpGet:
            path: ${HEALTH_ENDPOINT}
            port: ${PORT}
          initialDelaySeconds: 5
          periodSeconds: 10
---
apiVersion: v1
kind: Service
metadata:
  name: student-${USERNAME_LOWER}-svc
  namespace: ${NAMESPACE}
  labels:
    student: ${USERNAME_LOWER}
spec:
  selector:
    app: student-app
    student: ${USERNAME_LOWER}
  ports:
  - port: 80
    targetPort: ${PORT}
    protocol: TCP
    name: http
EOF

    echo "  ✅ Generated deployment and service for $USERNAME"
done

# Generate Gallery ConfigMap with student list
cat > "$OUTPUT_DIR/gallery-configmap.yaml" <<EOF
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: gallery-nginx-config
  namespace: ${NAMESPACE}
data:
  default.conf: |
    server {
        listen 80;
        server_name _;

        location / {
            root /usr/share/nginx/html;
            index index.html;
        }

        # API endpoint that returns student data
        location /api/students {
            default_type application/json;
            return 200 '{"students": ${STUDENT_LIST}}';
        }
    }
EOF

echo "✅ Generated gallery ConfigMap with $STUDENT_COUNT students"

# Generate Kustomization
cat > "$OUTPUT_DIR/kustomization.yaml" <<EOF
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: ${NAMESPACE}

resources:
  - namespace.yaml
  - gallery-configmap.yaml
EOF

# Add student manifests to kustomization
for file in "$OUTPUT_DIR"/student-*-deployment.yaml; do
    if [ -f "$file" ]; then
        basename "$file" >> "$OUTPUT_DIR/kustomization.yaml.tmp"
    fi
done

if [ -f "$OUTPUT_DIR/kustomization.yaml.tmp" ]; then
    sort "$OUTPUT_DIR/kustomization.yaml.tmp" | while read -r file; do
        echo "  - $file" >> "$OUTPUT_DIR/kustomization.yaml"
    done
    rm "$OUTPUT_DIR/kustomization.yaml.tmp"
fi

echo ""
echo "✅ Manifest generation complete!"
echo ""
echo "Generated files:"
ls -1 "$OUTPUT_DIR"/*.yaml | sed 's/^/  - /'

if [ "$DRY_RUN" == "dry-run" ]; then
    echo ""
    echo "📝 This was a dry-run. Files generated in $OUTPUT_DIR for review."
fi
