#!/bin/bash
# Start DataLive in development mode with MCP for workflow creation

echo "🚀 Starting DataLive in Development Mode"
echo "========================================"
echo ""
echo "This includes the N8N MCP server for workflow development."
echo "For production deployment, use: docker-compose up -d"
echo ""

# Start with development profile
docker-compose --profile development up -d

echo ""
echo "✅ DataLive Development Environment Started"
echo ""
echo "📡 Development Tools:"
echo "   • N8N MCP Server: Available for workflow creation"
echo "   • All standard DataLive services"
echo ""
echo "💡 When workflows are complete, restart without --profile development"