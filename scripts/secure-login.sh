#!/bin/bash
# Secure Quay.io login script using password-stdin

set -e

echo "╔════════════════════════════════════════════════════════════╗"
echo "║  Secure Quay.io Login                                      ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""
echo "Robot account: mpwbaruk+mpwrobot"
echo ""
echo "Enter your robot token (input will be hidden):"
read -s QUAY_TOKEN

# Use password-stdin for secure login
echo "$QUAY_TOKEN" | docker login quay.io -u "mpwbaruk+mpwrobot" --password-stdin

if [ $? -eq 0 ]; then
    echo ""
    echo "✓ Login successful!"
    echo ""
    echo "Credentials are stored securely in ~/.docker/config.json"
    echo "You can now run: make docker-build && make docker-push"
else
    echo ""
    echo "✗ Login failed. Please check your token."
    exit 1
fi

# Clean up the variable
unset QUAY_TOKEN
