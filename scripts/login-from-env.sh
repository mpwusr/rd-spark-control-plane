#!/bin/bash
# Login using environment variables from .env file

set -e

# Check if .env file exists
if [ ! -f .env ]; then
    echo "Error: .env file not found!"
    echo ""
    echo "Create .env file from template:"
    echo "  cp .env.template .env"
    echo ""
    echo "Then edit .env and add your credentials"
    exit 1
fi

# Load environment variables
source .env

# Validate variables
if [ -z "$QUAY_USERNAME" ] || [ -z "$QUAY_TOKEN" ]; then
    echo "Error: QUAY_USERNAME or QUAY_TOKEN not set in .env file"
    exit 1
fi

# Check if token looks like placeholder
if [ "$QUAY_TOKEN" = "your_robot_token_here" ]; then
    echo "Error: Please update QUAY_TOKEN in .env file with your actual token"
    exit 1
fi

echo "Logging in to Quay.io..."
echo "Username: $QUAY_USERNAME"

# Use password-stdin for secure login
echo "$QUAY_TOKEN" | docker login quay.io -u "$QUAY_USERNAME" --password-stdin

if [ $? -eq 0 ]; then
    echo ""
    echo "✓ Login successful!"
else
    echo ""
    echo "✗ Login failed"
    exit 1
fi
