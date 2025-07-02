# DataLive Healthcheck & Testing Sidecar
# Unified container for system validation, healthchecks, and comprehensive testing

FROM alpine:3.18

# Install required tools for healthchecks and testing
RUN apk add --no-cache \
    bash \
    curl \
    netcat-openbsd \
    python3 \
    py3-pip \
    py3-requests \
    jq \
    redis \
    && rm -rf /var/cache/apk/*

# Create working directory
WORKDIR /healthcheck

# Copy all healthcheck and test scripts
COPY verify.sh /healthcheck/
COPY quick-test.sh /healthcheck/
COPY test-functionality.sh /healthcheck/
COPY run-tests.sh /healthcheck/
COPY test-suite.py /healthcheck/
COPY test-api-key.py /healthcheck/
COPY test-redis-cache.py /healthcheck/

# Make all scripts executable
RUN chmod +x /healthcheck/*.sh /healthcheck/*.py

# Set environment
ENV PYTHONPATH=/healthcheck
ENV PATH="/healthcheck:$PATH"

# Create results directory
RUN mkdir -p /tmp/datalive-test-results

# Health check for the healthcheck container itself
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD echo "Healthcheck sidecar ready"

# Default command runs system verification
CMD ["./verify.sh"]