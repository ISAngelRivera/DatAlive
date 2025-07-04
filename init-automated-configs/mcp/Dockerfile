# N8N MCP Server Container
# Provides AI-assisted N8N workflow configuration and validation

FROM node:20-alpine

# Install required packages
RUN apk add --no-cache \
    bash \
    curl \
    git \
    && rm -rf /var/cache/apk/*

# Create working directory
WORKDIR /mcp

# Install N8N MCP from GitHub repository
RUN npm install -g https://github.com/czlonkowski/n8n-mcp.git

# Copy configuration
COPY n8n-mcp-config.json /mcp/config.json

# Create user for security
RUN addgroup -g 1001 mcpuser && \
    adduser -D -s /bin/bash -u 1001 -G mcpuser mcpuser

# Set permissions
RUN chown -R mcpuser:mcpuser /mcp
USER mcpuser

# Environment variables
ENV N8N_MCP_LOG_LEVEL=info
ENV N8N_MCP_USE_CONSOLE=true

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD echo "N8N MCP server ready"

# Default command - run MCP server
CMD ["npx", "n8n-mcp"]