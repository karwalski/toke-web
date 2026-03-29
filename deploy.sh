#!/usr/bin/env bash
# deploy.sh — Build and deploy tokelang.dev to AWS Lightsail (Bitnami Nginx)
#
# Usage:
#   ./deploy.sh                    # build + deploy
#   ./deploy.sh --build-only       # build locally, don't deploy
#   ./deploy.sh --deploy-only      # deploy existing dist/, skip build
#   ./deploy.sh --setup            # first-time server setup (run once)
#
# Environment variables (set in .env or export before running):
#   LIGHTSAIL_HOST   — public IP or hostname of the Lightsail instance
#   LIGHTSAIL_USER   — SSH user (default: bitnami)
#   LIGHTSAIL_KEY    — path to SSH private key
#   DOMAIN           — domain name (default: tokelang.dev)

set -euo pipefail

# ── Configuration ──────────────────────────────────────────────────────

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${SCRIPT_DIR}/.env"

# Load .env if present
if [[ -f "$ENV_FILE" ]]; then
    # shellcheck source=/dev/null
    source "$ENV_FILE"
fi

HOST="${LIGHTSAIL_HOST:?'Set LIGHTSAIL_HOST (IP or hostname) in .env or environment'}"
USER="${LIGHTSAIL_USER:-bitnami}"
KEY="${LIGHTSAIL_KEY:?'Set LIGHTSAIL_KEY (path to SSH key) in .env or environment'}"
DOMAIN="${DOMAIN:-tokelang.dev}"

REMOTE_ROOT="/opt/bitnami/nginx/html/${DOMAIN}"
DIST_DIR="${SCRIPT_DIR}/dist"
SSH_OPTS="-i ${KEY} -o StrictHostKeyChecking=accept-new -o ConnectTimeout=10"

# ── Helpers ────────────────────────────────────────────────────────────

log()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
ok()   { printf '\033[1;32m OK\033[0m %s\n' "$*"; }
err()  { printf '\033[1;31mERR\033[0m %s\n' "$*" >&2; }
die()  { err "$@"; exit 1; }

ssh_run() {
    # shellcheck disable=SC2086
    ssh ${SSH_OPTS} "${USER}@${HOST}" "$@"
}

rsync_to() {
    # shellcheck disable=SC2086
    rsync -az --delete \
        -e "ssh ${SSH_OPTS}" \
        "$1" "${USER}@${HOST}:$2"
}

# ── Build ──────────────────────────────────────────────────────────────

build() {
    log "Installing dependencies"
    cd "$SCRIPT_DIR"
    npm ci --prefer-offline 2>/dev/null || npm install

    log "Building site"
    npm run build

    # Verify output
    [[ -f "${DIST_DIR}/index.html" ]] || die "Build failed — dist/index.html not found"

    local page_count
    page_count=$(find "$DIST_DIR" -name "*.html" | wc -l | tr -d ' ')
    ok "Built ${page_count} pages → ${DIST_DIR}"
}

# ── Server Setup (first-time) ─────────────────────────────────────────

setup_server() {
    log "Setting up Lightsail server (first-time)"

    log "Creating site directory"
    ssh_run "sudo mkdir -p ${REMOTE_ROOT} && sudo chown ${USER}:daemon ${REMOTE_ROOT}"

    log "Writing Nginx server block"
    ssh_run "sudo tee /opt/bitnami/nginx/conf/server_blocks/${DOMAIN}.conf > /dev/null" << NGINX_EOF
server {
    listen 80;
    listen [::]:80;
    server_name ${DOMAIN} www.${DOMAIN};

    root ${REMOTE_ROOT};
    index index.html;

    # Gzip static assets
    gzip on;
    gzip_types text/plain text/css application/javascript application/json image/svg+xml;
    gzip_min_length 256;
    gzip_vary on;

    # Cache static assets (CSS/JS/fonts/images)
    location /_astro/ {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }

    # Pagefind search index
    location /pagefind/ {
        expires 1d;
        add_header Cache-Control "public";
    }

    # Favicon
    location = /favicon.svg {
        expires 30d;
    }

    # Clean URLs — try file, then directory, then 404
    location / {
        try_files \$uri \$uri/ \$uri/index.html =404;
    }

    # Custom 404
    error_page 404 /404.html;
    location = /404.html {
        internal;
    }

    # Security headers
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;

    # Block dotfiles
    location ~ /\. {
        deny all;
    }
}
NGINX_EOF

    log "Testing Nginx configuration"
    ssh_run "sudo /opt/bitnami/nginx/sbin/nginx -t" || die "Nginx config test failed"

    log "Restarting Nginx"
    ssh_run "sudo /opt/bitnami/ctlscript.sh restart nginx"

    ok "Server setup complete"
    echo ""
    log "Next steps:"
    echo "  1. Point DNS: ${DOMAIN} → ${HOST} (A record)"
    echo "  2. Point DNS: www.${DOMAIN} → ${HOST} (A record or CNAME)"
    echo "  3. Run: ./deploy.sh --setup-ssl   to enable HTTPS"
    echo "  4. Run: ./deploy.sh               to deploy the site"
}

# ── SSL Setup ─────────────────────────────────────────────────────────

setup_ssl() {
    log "Setting up Let's Encrypt SSL for ${DOMAIN}"

    ssh_run "sudo /opt/bitnami/bncert-tool <<SSL_INPUT
${DOMAIN} www.${DOMAIN}
Y
Y
Y
matt@tokelang.dev


Y
SSL_INPUT" || {
        echo ""
        log "If bncert-tool failed, run it interactively on the server:"
        echo "  ssh ${SSH_OPTS} ${USER}@${HOST}"
        echo "  sudo /opt/bitnami/bncert-tool"
    }

    ok "SSL setup complete — site available at https://${DOMAIN}"
}

# ── Deploy ─────────────────────────────────────────────────────────────

deploy() {
    [[ -d "$DIST_DIR" ]] || die "No dist/ directory. Run with --build-only first, or without flags."
    [[ -f "${DIST_DIR}/index.html" ]] || die "dist/index.html not found — build may have failed"

    local page_count
    page_count=$(find "$DIST_DIR" -name "*.html" | wc -l | tr -d ' ')

    log "Deploying ${page_count} pages to ${HOST}:${REMOTE_ROOT}"

    # Ensure target exists
    ssh_run "test -d ${REMOTE_ROOT}" || die "Remote directory missing. Run ./deploy.sh --setup first."

    # Sync dist/ contents
    rsync_to "${DIST_DIR}/" "${REMOTE_ROOT}/"

    ok "Deployed to ${HOST}"

    # Verify
    log "Verifying deployment"
    local status
    status=$(ssh_run "curl -s -o /dev/null -w '%{http_code}' http://localhost:80/ --resolve '${DOMAIN}:80:127.0.0.1' -H 'Host: ${DOMAIN}'" 2>/dev/null || echo "000")

    if [[ "$status" == "200" ]]; then
        ok "Site responding (HTTP ${status})"
    else
        err "Site returned HTTP ${status} — check Nginx logs"
        echo "  ssh ${SSH_OPTS} ${USER}@${HOST} sudo tail -20 /opt/bitnami/nginx/logs/error.log"
    fi

    echo ""
    echo "  http://${DOMAIN}"
    echo "  https://${DOMAIN}  (if SSL configured)"
}

# ── Main ───────────────────────────────────────────────────────────────

main() {
    case "${1:-}" in
        --build-only)
            build
            ;;
        --deploy-only)
            deploy
            ;;
        --setup)
            setup_server
            ;;
        --setup-ssl)
            setup_ssl
            ;;
        --help|-h)
            echo "Usage: ./deploy.sh [--build-only|--deploy-only|--setup|--setup-ssl|--help]"
            echo ""
            echo "  (no flags)     Build and deploy"
            echo "  --build-only   Build locally, don't deploy"
            echo "  --deploy-only  Deploy existing dist/"
            echo "  --setup        First-time server setup (Nginx config)"
            echo "  --setup-ssl    Configure Let's Encrypt SSL"
            echo ""
            echo "Set LIGHTSAIL_HOST, LIGHTSAIL_KEY in .env"
            ;;
        "")
            build
            deploy
            ;;
        *)
            die "Unknown option: $1 — try --help"
            ;;
    esac
}

main "$@"
