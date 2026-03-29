#!/bin/bash
# Lightsail Launch Script — tokelang.dev
# Paste this into: Create Instance → Add launch script
#
# Bitnami Nginx 1.28.2 on Ubuntu
# Runs once on first boot to configure the server for tokelang.dev

set -euo pipefail
exec > /var/log/tokelang-launch.log 2>&1
echo "==> tokelang.dev launch script started at $(date -u)"

DOMAIN="tokelang.dev"
SITE_ROOT="/opt/bitnami/nginx/html/${DOMAIN}"
REPO="https://github.com/karwalski/toke-web.git"
NODE_VERSION="20"

# ── 1. System updates ─────────────────────────────────────────────────

echo "==> Updating system packages"
apt-get update -qq
apt-get upgrade -y -qq

# ── 2. Install Node.js ────────────────────────────────────────────────

echo "==> Installing Node.js ${NODE_VERSION}"
if ! command -v node &>/dev/null; then
    curl -fsSL https://deb.nodesource.com/setup_${NODE_VERSION}.x | bash -
    apt-get install -y -qq nodejs
fi
echo "    node $(node --version), npm $(npm --version)"

# ── 3. Install Git (if missing) ───────────────────────────────────────

if ! command -v git &>/dev/null; then
    echo "==> Installing git"
    apt-get install -y -qq git
fi

# ── 4. Clone and build the site ───────────────────────────────────────

echo "==> Cloning ${REPO}"
BUILD_DIR="/tmp/toke-web-build"
rm -rf "${BUILD_DIR}"
git clone --depth 1 "${REPO}" "${BUILD_DIR}"

echo "==> Installing dependencies"
cd "${BUILD_DIR}"
npm ci --prefer-offline 2>/dev/null || npm install

echo "==> Building site"
npm run build

# Verify
if [[ ! -f "${BUILD_DIR}/dist/index.html" ]]; then
    echo "ERR: Build failed — dist/index.html not found"
    exit 1
fi
PAGE_COUNT=$(find "${BUILD_DIR}/dist" -name "*.html" | wc -l)
echo "    Built ${PAGE_COUNT} pages"

# ── 5. Deploy to Nginx document root ──────────────────────────────────

echo "==> Deploying to ${SITE_ROOT}"
mkdir -p "${SITE_ROOT}"
rsync -a --delete "${BUILD_DIR}/dist/" "${SITE_ROOT}/"
chown -R bitnami:daemon "${SITE_ROOT}"

# ── 6. Configure Nginx server block ───────────────────────────────────

echo "==> Writing Nginx server block"
mkdir -p /opt/bitnami/nginx/conf/server_blocks

cat > "/opt/bitnami/nginx/conf/server_blocks/${DOMAIN}.conf" << 'NGINX_EOF'
server {
    listen 80;
    listen [::]:80;
    server_name tokelang.dev www.tokelang.dev;

    root /opt/bitnami/nginx/html/tokelang.dev;
    index index.html;

    # Gzip static assets
    gzip on;
    gzip_types text/plain text/css application/javascript application/json image/svg+xml;
    gzip_min_length 256;
    gzip_vary on;

    # Cache hashed assets (CSS/JS from Astro)
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

    # Clean URLs
    location / {
        try_files $uri $uri/ $uri/index.html =404;
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
    add_header X-XSS-Protection "1; mode=block" always;

    # Block dotfiles
    location ~ /\. {
        deny all;
    }
}
NGINX_EOF

# ── 7. Test and restart Nginx ─────────────────────────────────────────

echo "==> Testing Nginx configuration"
/opt/bitnami/nginx/sbin/nginx -t

echo "==> Restarting Nginx"
/opt/bitnami/ctlscript.sh restart nginx

# ── 8. Set up Let's Encrypt SSL ───────────────────────────────────────

echo "==> Configuring Let's Encrypt SSL"
# bncert-tool needs DNS to be pointing at this instance already.
# If DNS isn't ready, this will fail gracefully and can be run later:
#   sudo /opt/bitnami/bncert-tool

if host "${DOMAIN}" &>/dev/null; then
    echo "    DNS resolves — attempting SSL setup"
    /opt/bitnami/bncert-tool --domain "${DOMAIN},www.${DOMAIN}" \
        --email "matt@tokelang.dev" \
        --agree-tos \
        --redirect \
        --force-renewal 2>/dev/null || {
        echo "    SSL auto-setup failed (DNS may not be ready yet)"
        echo "    Run manually after DNS propagates: sudo /opt/bitnami/bncert-tool"
    }
else
    echo "    DNS not resolving yet — skipping SSL"
    echo "    Run manually after DNS propagates: sudo /opt/bitnami/bncert-tool"
fi

# ── 9. Set up auto-deploy via cron ────────────────────────────────────

echo "==> Setting up daily auto-deploy cron"
cat > /opt/bitnami/scripts/redeploy-tokelang.sh << 'CRON_EOF'
#!/bin/bash
# Pull latest toke-web, rebuild, and deploy
set -euo pipefail
BUILD_DIR="/tmp/toke-web-build"
SITE_ROOT="/opt/bitnami/nginx/html/tokelang.dev"

cd "${BUILD_DIR}" 2>/dev/null || {
    git clone --depth 1 https://github.com/karwalski/toke-web.git "${BUILD_DIR}"
    cd "${BUILD_DIR}"
}

git fetch --depth 1 origin main
LOCAL=$(git rev-parse HEAD)
REMOTE=$(git rev-parse origin/main)

if [[ "$LOCAL" == "$REMOTE" ]]; then
    echo "$(date -u) — no changes"
    exit 0
fi

git reset --hard origin/main
npm ci --prefer-offline 2>/dev/null || npm install
npm run build

if [[ -f dist/index.html ]]; then
    rsync -a --delete dist/ "${SITE_ROOT}/"
    chown -R bitnami:daemon "${SITE_ROOT}"
    echo "$(date -u) — deployed $(git rev-parse --short HEAD)"
else
    echo "$(date -u) — build failed, keeping current version"
    exit 1
fi
CRON_EOF
chmod +x /opt/bitnami/scripts/redeploy-tokelang.sh

# Run every 15 minutes, log to syslog
(crontab -l 2>/dev/null; echo "*/15 * * * * /opt/bitnami/scripts/redeploy-tokelang.sh >> /var/log/tokelang-deploy.log 2>&1") | sort -u | crontab -

# ── 10. Cleanup ───────────────────────────────────────────────────────

echo "==> Cleaning up"
rm -rf "${BUILD_DIR}/node_modules/.cache" 2>/dev/null || true
apt-get autoremove -y -qq
apt-get clean -qq

# ── Done ──────────────────────────────────────────────────────────────

echo ""
echo "==> tokelang.dev launch complete at $(date -u)"
echo "    Site root:  ${SITE_ROOT}"
echo "    Pages:      ${PAGE_COUNT}"
echo "    Auto-deploy: every 15 min from ${REPO}"
echo "    SSL:        run 'sudo /opt/bitnami/bncert-tool' if not configured above"
echo "    Logs:       /var/log/tokelang-launch.log"
echo "                /var/log/tokelang-deploy.log"
