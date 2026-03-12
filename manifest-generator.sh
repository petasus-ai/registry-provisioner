#!/bin/bash

# ==============================================================================
# Kubernetes Manifest Generator for Harbor Registry (Template Based)
# ==============================================================================

usage() {
    echo "Usage:"
    echo "  $0 mgmt [ADMIN_PASSWORD]      - Generate Management cluster manifests."
    echo "  $0 workload <GATEWAY_IP>      - Generate Workload cluster manifests."
    echo ""
    echo "Examples:"
    echo "  $0 mgmt \"MySecurePassword123!\""
    echo "  $0 workload 192.168.100.10"
    exit 1
}

validate_ip() {
    local ip=$1
    if [[ $ip =~ ^([0-9]{1,3})\.([0-9]{1,3})\.([0-9]{1,3})\.([0-9]{1,3})$ ]]; then
        if [[ ${BASH_REMATCH[1]} -le 255 && ${BASH_REMATCH[2]} -le 255 && \
              ${BASH_REMATCH[3]} -le 255 && ${BASH_REMATCH[4]} -le 255 ]]; then
            return 0
        fi
    fi
    return 1
}

if [[ "$1" == "-h" || "$1" == "--help" || -z "$1" ]]; then
    usage
fi

MODE=$1

# Load Global Configuration
if [ -f "config.env" ]; then
    source config.env
else
    echo "[ERROR] config.env file not found. Please create it first."
    exit 1
fi

# Path Definitions
CA_CRT="$CERT_DIR/ca.crt"
SERVER_CRT="$CERT_DIR/${DOMAIN}.crt"
SERVER_KEY="$CERT_DIR/${DOMAIN}.key"
MGMT_DIR="manifests/management"
WORKLOAD_DIR="manifests/workload"

# Pre-flight Check for Certificates
if [ ! -f "$CA_CRT" ] || [ ! -f "$SERVER_CRT" ] || [ ! -f "$SERVER_KEY" ]; then
    echo "[ERROR] Required certificates not found. Please run cert-generator.sh first."
    exit 1
fi

TLS_CRT_B64=$(cat "$SERVER_CRT" | base64 | tr -d '\n')
TLS_KEY_B64=$(cat "$SERVER_KEY" | base64 | tr -d '\n')

# ==============================================================================
# Mode: Management
# ==============================================================================
if [ "$MODE" == "mgmt" ]; then
    HARBOR_ADMIN_PASSWORD=${2:-"PetasusAdmin123!"}

    echo "=== Generating Management Manifests ==="
    mkdir -p "$MGMT_DIR"

    echo "-> Rendering Management Secret..."
    sed -e "s|{{NAMESPACE}}|$NAMESPACE|g" \
        -e "s|{{TLS_CRT_B64}}|$TLS_CRT_B64|g" \
        -e "s|{{TLS_KEY_B64}}|$TLS_KEY_B64|g" \
        "$TEMPLATE_DIR/mgmt-secret.yaml.tmpl" > "$MGMT_DIR/mgmt-secret.yaml"

    echo "-> Rendering Gateway API Manifest..."
    sed -e "s|{{NAMESPACE}}|$NAMESPACE|g" \
        -e "s|{{DOMAIN}}|$DOMAIN|g" \
        -e "s|{{GATEWAY_CLASS}}|$GATEWAY_CLASS|g" \
        "$TEMPLATE_DIR/harbor-gateway.yaml.tmpl" > "$MGMT_DIR/harbor-gateway.yaml"

    echo "-> Rendering Harbor Helm Values..."
    sed -e "s|{{DOMAIN}}|$DOMAIN|g" \
        -e "s|{{HARBOR_ADMIN_PASSWORD}}|$HARBOR_ADMIN_PASSWORD|g" \
        "$TEMPLATE_DIR/harbor-values.yaml.tmpl" > "$MGMT_DIR/harbor-values.yaml"

    echo "=== Completed. Files are in '$MGMT_DIR'. ==="

# ==============================================================================
# Mode: Workload
# ==============================================================================
elif [ "$MODE" == "workload" ]; then
    GATEWAY_IP=$2

    if [ -z "$GATEWAY_IP" ]; then
        echo "[ERROR] GATEWAY_IP is required for workload manifests."
        usage
    fi

    if ! validate_ip "$GATEWAY_IP"; then
        echo "[ERROR] Invalid IP address format: $GATEWAY_IP"
        exit 1
    fi

    echo "=== Generating Workload Manifests ==="
    mkdir -p "$WORKLOAD_DIR"

    INDENTED_CA_TMP="$WORKLOAD_DIR/.ca.crt.tmp"
    awk '{print "    " $0}' "$CA_CRT" > "$INDENTED_CA_TMP"

    echo "-> Rendering Workload Setup (ConfigMap + DaemonSet)..."
    sed -e "s|{{GATEWAY_IP}}|$GATEWAY_IP|g" \
        -e "s|{{DOMAIN}}|$DOMAIN|g" \
        -e '/{{CA_CRT_INDENTED}}/r '"$INDENTED_CA_TMP"'' \
        -e '/{{CA_CRT_INDENTED}}/d' \
        "$TEMPLATE_DIR/workload-setup.yaml.tmpl" > "$WORKLOAD_DIR/workload-setup.yaml"

    rm -f "$INDENTED_CA_TMP"
    echo "=== Completed. Files are in '$WORKLOAD_DIR'. ==="

else
    echo "[ERROR] Unknown mode: $MODE"
    usage
fi
