# Spotify MCP Server (HTTP)

Dockerized [Spotify MCP server](https://github.com/marcelmarais/spotify-mcp-server) exposed as an HTTP endpoint via [supergateway](https://github.com/supercorp-ai/supergateway). Connect any MCP-compatible client over Streamable HTTP instead of stdio.

## Prerequisites

- Docker and Docker Compose
- Spotify Premium account
- Spotify Developer App credentials (see below)

## Quick Start

### 1. Create a Spotify Developer App

1. Go to [Spotify Developer Dashboard](https://developer.spotify.com/dashboard/)
2. Create a new app
3. Set the redirect URI to `http://127.0.0.1:8888/callback`
4. Copy your **Client ID** and **Client Secret**
5. Add your Spotify account under **User Management** (required for dev mode apps)

### 2. Get OAuth Tokens

You need to run the auth flow locally once to get your access and refresh tokens:

```fish
cd spotify-mcp-server
npm install && npm run build
npm run auth
```

This opens a browser for Spotify OAuth. After approving, tokens are saved to `spotify-mcp-server/spotify-config.json`. Copy the values from that file into your `.env`.

### 3. Configure environment

```fish
cp .env.example .env
```

Edit `.env` with your credentials:

```
SPOTIFY_CLIENT_ID=your-client-id
SPOTIFY_CLIENT_SECRET=your-client-secret
SPOTIFY_REDIRECT_URI=http://127.0.0.1:8888/callback
SPOTIFY_ACCESS_TOKEN=from-spotify-config.json
SPOTIFY_REFRESH_TOKEN=from-spotify-config.json
SPOTIFY_EXPIRES_AT=from-spotify-config.json
```

### 4. Run

```fish
docker compose up -d
```

The MCP server is now available at `http://localhost:8000/mcp` (Streamable HTTP).

### 5. Connect a client

Point any MCP client at the HTTP endpoint. For example, in an `.mcp.json`:

```json
{
  "mcpServers": {
    "spotify": {
      "type": "streamable-http",
      "url": "http://localhost:8000/mcp"
    }
  }
}
```

## Building Manually

```fish
docker build -t spotify-mcp-http .
docker run --env-file .env -p 8000:8000 spotify-mcp-http
```

## Common Issues

### "Insecure redirect URI" when saving in Spotify Dashboard

Spotify no longer accepts `localhost` in redirect URIs. Use the loopback IP instead:

- `http://127.0.0.1:8888/callback` (works)
- `http://localhost:8888/callback` (rejected)

### "Something went wrong" on the Spotify authorization page

Your app is in development mode. Add your Spotify account under **User Management** in the Developer Dashboard.

### Token expiration

The MCP server auto-refreshes tokens using the refresh token. If auth errors persist, re-run `npm run auth` locally and update the `.env` with the new tokens.

## Local Development (without Docker)

If you want to run the MCP server directly via stdio (e.g., for Claude Code):

```fish
cd spotify-mcp-server
npm install && npm run build
npm run auth  # first time only
```

Then use the stdio transport in `.mcp.json`:

```json
{
  "mcpServers": {
    "spotify": {
      "command": "node",
      "args": ["/path/to/spotify-mcp-server/build/index.js"]
    }
  }
}
```
