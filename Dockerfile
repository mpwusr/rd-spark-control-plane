FROM apache/spark:3.5.4

USER root

# Download Hadoop AWS and AWS SDK JARs for S3A support
# Using versions compatible with Spark 3.5.4 and Hadoop 3.3.4
RUN cd /opt/spark/jars && \
    wget -q https://repo1.maven.org/maven2/org/apache/hadoop/hadoop-aws/3.3.4/hadoop-aws-3.3.4.jar && \
    wget -q https://repo1.maven.org/maven2/com/amazonaws/aws-java-sdk-bundle/1.12.262/aws-java-sdk-bundle-1.12.262.jar && \
    chmod 644 *.jar

# Switch back to non-root user
USER 185

# Verify JARs are present
RUN ls -lh /opt/spark/jars/hadoop-aws-*.jar /opt/spark/jars/aws-java-sdk-bundle-*.jar
