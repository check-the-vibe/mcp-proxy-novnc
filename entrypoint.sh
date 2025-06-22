#!/bin/bash


npm install -g @anthropic-ai/claude-code
su - vibe -c "pip install uv"
su - vibe -c "uv tool install mcp-proxy"


echo "Starting supervisord..."
exec /usr/bin/supervisord -c /etc/supervisor/conf.d/supervisord.conf
