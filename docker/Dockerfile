FROM apache/spark:3.5.4

USER root

# Download Hadoop AWS and AWS SDK JARs for S3A support
RUN cd /opt/spark/jars && \
    wget https://repo1.maven.org/maven2/org/apache/hadoop/hadoop-aws/3.3.4/hadoop-aws-3.3.4.jar && \
    wget https://repo1.maven.org/maven2/com/amazonaws/aws-java-sdk-bundle/1.12.262/aws-java-sdk-bundle-1.12.262.jar && \
    chmod 644 hadoop-aws-3.3.4.jar aws-java-sdk-bundle-1.12.262.jar && \
    ls -lh hadoop-aws-*.jar aws-java-sdk-bundle-*.jar

# Switch back to spark user
USER 185
