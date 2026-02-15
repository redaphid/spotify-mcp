#!/bin/sh
set -e

CONFIG_FILE="/app/spotify-mcp-server/spotify-config.json"

# Generate spotify-config.json from environment variables
cat > "$CONFIG_FILE" <<EOF
{
  "clientId": "${SPOTIFY_CLIENT_ID}",
  "clientSecret": "${SPOTIFY_CLIENT_SECRET}",
  "redirectUri": "${SPOTIFY_REDIRECT_URI:-http://127.0.0.1:8888/callback}",
  "accessToken": "${SPOTIFY_ACCESS_TOKEN}",
  "refreshToken": "${SPOTIFY_REFRESH_TOKEN}",
  "expiresAt": ${SPOTIFY_EXPIRES_AT:-0}
}
EOF

echo "Generated spotify-config.json"

exec npx supergateway \
  --stdio "node /app/spotify-mcp-server/build/index.js" \
  --port 8000 \
  --cors \
  --outputTransport streamableHttp
