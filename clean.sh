#!/bin/bash

# ==============================================================================
# Workspace Cleanup Script for Registry Provisioner
# ==============================================================================
# This script securely removes all auto-generated directories and files,
# resetting the workspace to its initial state.

# ------------------------------------------------------------------------------
# 1. Target Directories Definition
# ------------------------------------------------------------------------------

# Load Global Configuration
if [ -f "config.env" ]; then
    source config.env
else
    echo "[ERROR] config.env file not found."
    exit 1
fi

echo "=== Starting Workspace Cleanup ==="

# ------------------------------------------------------------------------------
# 2. Cleanup Logic
# ------------------------------------------------------------------------------

# Remove the certificate directory if it exists
if [ -d "$CERT_DIR" ]; then
    echo "-> Removing generated certificates directory: $CERT_DIR"
    rm -rf "$CERT_DIR"
else
    echo "-> Certificate directory '$CERT_DIR' does not exist. Skipping."
fi

# Remove the manifests directory if it exists
if [ -d "$MANIFEST_DIR" ]; then
    echo "-> Removing generated manifests directory: $MANIFEST_DIR"
    rm -rf "$MANIFEST_DIR"
else
    echo "-> Manifests directory '$MANIFEST_DIR' does not exist. Skipping."
fi

# Remove any lingering temporary files just in case
if [ -f ".ca.crt.tmp" ]; then
    echo "-> Removing lingering temporary files..."
    rm -f ".ca.crt.tmp"
fi

# ------------------------------------------------------------------------------
# 3. Finalization
# ------------------------------------------------------------------------------
echo "=== Cleanup Completed Successfully ==="
echo "Your workspace is now clean and ready for a fresh generation."
