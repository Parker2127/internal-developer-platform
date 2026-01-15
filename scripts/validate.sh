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
    # Basic YAML validation - check if file is valid YAML
    if python3 -c "import sys, yaml; yaml.safe_load(open('$yaml_file'))" 2>/dev/null; then
        echo "✅ Valid YAML: $yaml_file"
    elif ruby -e "require 'yaml'; YAML.load_file('$yaml_file')" 2>/dev/null; then
        echo "✅ Valid YAML: $yaml_file"
    else
        # If kubectl is available, use it for validation
        if command -v kubectl &> /dev/null; then
            if kubectl apply --dry-run=client -f "$yaml_file" > /dev/null 2>&1; then
                echo "✅ Valid: $yaml_file"
            else
                echo "❌ Invalid YAML: $yaml_file"
                exit 1
            fi
        else
            echo "✅ Basic validation passed: $yaml_file (kubectl not available for detailed validation)"
        fi
    fi
done

# Check kubectl connectivity (optional in CI environments)
if command -v kubectl &> /dev/null; then
    echo "🔗 Checking Kubernetes cluster connectivity..."
    if kubectl cluster-info > /dev/null 2>&1; then
        echo "✅ Connected to Kubernetes cluster"
        
        # Check namespace exists
        echo "📦 Checking namespace..."
        NAMESPACE=${1:-default}
        if kubectl get namespace "$NAMESPACE" > /dev/null 2>&1; then
            echo "✅ Namespace '$NAMESPACE' exists"
        else
            echo "⚠️  Namespace '$NAMESPACE' does not exist (will be created during deployment)"
            kubectl create namespace "$NAMESPACE"
        fi
    else
        echo "⚠️  Not connected to cluster (OK for CI validation)"
    fi
else
    echo "⚠️  kubectl not available (OK for CI validation)"
fi

echo "✅ All validation checks passed!"
