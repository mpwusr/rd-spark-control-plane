#!/bin/bash
set -e
if [ ! -f .env ]; then
    echo "Error: .env file not found!"
    exit 1
fi
source .env
if [ -z "$QUAY_USERNAME" ] || [ -z "$QUAY_TOKEN" ]; then
    echo "Error: QUAY_USERNAME or QUAY_TOKEN not set"
    exit 1
fi
echo "Logging in to Quay.io..."
echo "Username: $QUAY_USERNAME"
echo "$QUAY_TOKEN" | docker login quay.io -u "$QUAY_USERNAME" --password-stdin
echo ""
echo "Login successful!"
