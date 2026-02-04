#!/bin/bash
# Quick Start Script for Building and Pushing Spark S3A Image to Quay.io

set -e

echo "╔════════════════════════════════════════════════════════════╗"
echo "║  Spark S3A Image Builder for Quay.io                      ║"
echo "║  Username: mpwbaruk                                        ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

# Step 1: Build
echo "→ Step 1: Building Docker image..."
docker build -t quay.io/mpwbaruk/spark-s3a:3.5.4 -f Dockerfile .
docker tag quay.io/mpwbaruk/spark-s3a:3.5.4 quay.io/mpwbaruk/spark-s3a:latest
echo "✓ Image built successfully"
echo ""

# Step 2: Test
echo "→ Step 2: Testing image..."
docker run --rm quay.io/mpwbaruk/spark-s3a:3.5.4 ls -lh /opt/spark/jars/hadoop-aws-*.jar
docker run --rm quay.io/mpwbaruk/spark-s3a:3.5.4 ls -lh /opt/spark/jars/aws-java-sdk-bundle-*.jar
echo "✓ S3A JARs verified"
echo ""

# Step 3: Login prompt
echo "→ Step 3: Login to Quay.io"
echo "Running: docker login quay.io"
docker login quay.io
echo ""

# Step 4: Push
echo "→ Step 4: Pushing to Quay.io..."
docker push quay.io/mpwbaruk/spark-s3a:3.5.4
docker push quay.io/mpwbaruk/spark-s3a:latest
echo "✓ Images pushed successfully"
echo ""

# Final instructions
echo "╔════════════════════════════════════════════════════════════╗"
echo "║  SUCCESS! Next Steps:                                      ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""
echo "1. Make repository public (if not already):"
echo "   → https://quay.io/repository/mpwbaruk/spark-s3a?tab=settings"
echo ""
echo "2. Update your Terraform file to use:"
echo "   image = \"quay.io/mpwbaruk/spark-s3a:3.5.4\""
echo ""
echo "3. Deploy to Kubernetes:"
echo "   terraform destroy -target=kubernetes_deployment_v1.spark_history"
echo "   terraform apply"
echo ""
echo "Your image is available at:"
echo "   quay.io/mpwbaruk/spark-s3a:3.5.4"
echo "   quay.io/mpwbaruk/spark-s3a:latest"
echo ""
