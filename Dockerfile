FROM node:22-slim

WORKDIR /app

# Clone and build the upstream MCP server
RUN apt-get update && apt-get install -y git && rm -rf /var/lib/apt/lists/* \
    && git clone https://github.com/marcelmarais/spotify-mcp-server.git \
    && cd spotify-mcp-server \
    && npm install \
    && npm run build

# Install supergateway
RUN npm install -g supergateway

# Copy entrypoint
COPY entrypoint.sh /app/entrypoint.sh
RUN chmod +x /app/entrypoint.sh

EXPOSE 8000

ENTRYPOINT ["/app/entrypoint.sh"]
