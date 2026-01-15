#!/bin/bash
# Pre-deployment validation script
# Validates configuration files before deployment

set -e

echo "🔍 Running pre-deployment validation..."

# Check for required files
echo "📄 Checking required files..."
required_files=(
    "kubernetes/deployment.yaml"
    "kubernetes/service.yaml"
)

for file in "${required_files[@]}"; do
    if [ ! -f "$file" ]; then
        echo "❌ Missing required file: $file"
        exit 1
    fi
    echo "✅ Found: $file"
done

# Validate Kubernetes YAML syntax
echo "🔧 Validating Kubernetes YAML syntax..."
for yaml_file in kubernetes/*.yaml; do
    if kubectl apply --dry-run=client -f "$yaml_file" > /dev/null 2>&1; then
        echo "✅ Valid: $yaml_file"
    else
        echo "❌ Invalid YAML: $yaml_file"
        exit 1
    fi
done

# Check kubectl connectivity
echo "🔗 Checking Kubernetes cluster connectivity..."
if kubectl cluster-info > /dev/null 2>&1; then
    echo "✅ Connected to Kubernetes cluster"
else
    echo "❌ Cannot connect to Kubernetes cluster"
    exit 1
fi

# Check namespace exists
echo "📦 Checking namespace..."
NAMESPACE=${1:-default}
if kubectl get namespace "$NAMESPACE" > /dev/null 2>&1; then
    echo "✅ Namespace '$NAMESPACE' exists"
else
    echo "⚠️  Namespace '$NAMESPACE' does not exist, creating..."
    kubectl create namespace "$NAMESPACE"
fi

echo "✅ All validation checks passed!"
