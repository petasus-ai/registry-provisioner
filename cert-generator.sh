#!/bin/bash

# ==============================================================================
# OpenSSL CA & Server Certificate Automation Script
# ==============================================================================

# ------------------------------------------------------------------------------
# 1. User-Defined Variables
# ------------------------------------------------------------------------------

# Load Global Configuration
if [ -f "config.env" ]; then
    source config.env
else
    echo "[ERROR] config.env file not found. Please create it first."
    exit 1
fi

# Path Definitions
CA_KEY="$CERT_DIR/ca.key"
CA_CRT="$CERT_DIR/ca.crt"
CA_SRL="$CERT_DIR/ca.srl"
SERVER_KEY="$CERT_DIR/${DOMAIN}.key"
SERVER_CSR="$CERT_DIR/${DOMAIN}.csr"
SERVER_CRT="$CERT_DIR/${DOMAIN}.crt"
EXT_FILE="$CERT_DIR/v3.ext"

# ------------------------------------------------------------------------------
# 2. Environment Setup
# ------------------------------------------------------------------------------

# Remove the directory if it exists
if [ -d "$CERT_DIR" ]; then
    echo "-> Cleaning up existing certificate directory: $CERT_DIR"
    rm -rf "$CERT_DIR"
fi

echo "-> Creating fresh certificate directory: $CERT_DIR"
mkdir -p "$CERT_DIR"

# ------------------------------------------------------------------------------
# 3. Certificate Generation Logic
# ------------------------------------------------------------------------------

echo "=== Starting certificate generation in [$CERT_DIR] ==="

# [Step 1] Generate Root CA
echo "-> 1. Generating Root CA Private Key..."
openssl genrsa -out "$CA_KEY" "$KEY_SIZE"

echo "-> 2. Generating Root CA Certificate..."
openssl req -x509 -new -nodes -sha512 -days "$DAYS" \
  -subj "/C=$COUNTRY/ST=$STATE/L=$LOCALITY/O=$ORG/OU=$OU/CN=$CA_CN" \
  -key "$CA_KEY" -out "$CA_CRT"

# [Step 2] Generate Server Certificate Signing Request (CSR)
echo "-> 3. Generating Server Private Key..."
openssl genrsa -out "$SERVER_KEY" "$KEY_SIZE"

echo "-> 4. Generating Server CSR..."
openssl req -new -sha512 \
  -subj "/C=$COUNTRY/ST=$STATE/L=$LOCALITY/O=$ORG/OU=$OU/CN=$DOMAIN" \
  -key "$SERVER_KEY" -out "$SERVER_CSR"

# [Step 3] Create x509 v3 extension configuration file
echo "-> 5. Creating x509 v3 extension file..."
cat > "$EXT_FILE" <<-EOF
authorityKeyIdentifier=keyid,issuer
basicConstraints=CA:FALSE
keyUsage = digitalSignature, nonRepudiation, keyEncipherment, dataEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names
[alt_names]
DNS.1=$DOMAIN
EOF

# [Step 4] Issue the Server Certificate
echo "-> 6. Issuing Server Certificate signed by the Root CA..."
openssl x509 -req -sha512 -days "$DAYS" \
  -extfile "$EXT_FILE" \
  -CA "$CA_CRT" -CAkey "$CA_KEY" -CAcreateserial \
  -in "$SERVER_CSR" -out "$SERVER_CRT"

# ------------------------------------------------------------------------------
# 4. Finalization
# ------------------------------------------------------------------------------

echo "=== Certificate generation completed successfully ==="
echo "All files are located in: $(pwd)/$CERT_DIR"
ls -lh "$CERT_DIR"
