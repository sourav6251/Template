#!/bin/bash

# Keycloak Setup Script - Fixed with SSL
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
DOMAIN="login.sourav.fun"
DB_HOST="103.49.131.57"
DB_PORT="5432"
DB_NAME="mydb"
DB_USER="myuser"
DB_PASS="sourav"
DB_SCHEMA="keycloak"
KEYCLOAK_ADMIN_USER="admin"
KEYCLOAK_ADMIN_PASS="password123"

# Function to print colored output
print_status() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    print_error "Please run as root or with sudo"
    exit 1
fi

print_status "Starting Keycloak setup for: $DOMAIN"

# Step 1: Stop and clean up existing services
print_status "Step 1: Cleaning up existing services..."
systemctl stop nginx 2>/dev/null || true
docker stop keycloak 2>/dev/null || true
docker rm keycloak 2>/dev/null || true

# Step 2: Remove old Nginx configurations
print_status "Step 2: Removing old Nginx configurations..."
rm -f /etc/nginx/sites-enabled/default 2>/dev/null || true
rm -f /etc/nginx/sites-available/$DOMAIN 2>/dev/null || true
rm -f /etc/nginx/sites-enabled/$DOMAIN 2>/dev/null || true

# Step 3: Create directory structure
print_status "Step 3: Creating directory structure..."
mkdir -p /opt/keycloak-setup
cd /opt/keycloak-setup

# Step 4: Create Docker Compose file
print_status "Step 4: Creating Docker Compose configuration..."
cat > docker-compose.yml << EOF
version: '3.8'

services:
  keycloak:
    image: quay.io/keycloak/keycloak:24.0.1
    container_name: keycloak
    environment:
      KC_HOSTNAME: $DOMAIN
      KC_HOSTNAME_STRICT: "false"
      KC_HOSTNAME_STRICT_HTTPS: "false"
      
      # Database configuration
      KC_DB: postgres
      KC_DB_URL: jdbc:postgresql://$DB_HOST:$DB_PORT/$DB_NAME
      KC_DB_USERNAME: $DB_USER
      KC_DB_PASSWORD: $DB_PASS
      KC_DB_SCHEMA: $DB_SCHEMA
      
      # Keycloak admin credentials
      KEYCLOAK_ADMIN: $KEYCLOAK_ADMIN_USER
      KEYCLOAK_ADMIN_PASSWORD: $KEYCLOAK_ADMIN_PASS
      
      # Other settings
      KC_HEALTH_ENABLED: "true"
      KC_METRICS_ENABLED: "true"
      KC_HTTP_ENABLED: "true"
      
      # Proxy settings for Nginx
      KC_PROXY: edge
      
    command:
      - start-dev
    ports:
      - "8080:8080"
    restart: unless-stopped
EOF

# Step 5: Start Keycloak first
print_status "Step 5: Starting Keycloak container..."
docker-compose up -d

print_status "Waiting for Keycloak to start (30 seconds)..."
sleep 30

# Check if Keycloak is running
if docker ps | grep -q keycloak; then
    print_success "Keycloak container is running"
else
    print_error "Keycloak container failed to start"
    docker logs keycloak
    exit 1
fi

# Test Keycloak health
if curl -s http://localhost:8080/health | grep -q "UP"; then
    print_success "Keycloak health check passed"
else
    print_warning "Keycloak health check failed, waiting longer..."
    sleep 30
fi

# Step 6: Create initial HTTP-only Nginx configuration
print_status "Step 6: Creating initial HTTP Nginx configuration..."
cat > /etc/nginx/sites-available/$DOMAIN << EOF
server {
    listen 80;
    server_name $DOMAIN;

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header Referrer-Policy "no-referrer-when-downgrade" always;

    # Keycloak proxy
    location / {
        proxy_pass http://127.0.0.1:8080;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header X-Forwarded-Host \$host;
        
        # WebSocket support
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        
        # Timeouts
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
        
        # Buffer settings
        proxy_buffering off;
        proxy_request_buffering off;
    }

    # Health check endpoint
    location /health {
        proxy_pass http://127.0.0.1:8080/health;
        proxy_set_header Host \$host;
        access_log off;
    }
}
EOF

# Enable the site
ln -sf /etc/nginx/sites-available/$DOMAIN /etc/nginx/sites-enabled/

# Test Nginx configuration
print_status "Testing Nginx configuration..."
if nginx -t; then
    print_success "Nginx configuration test passed"
else
    print_error "Nginx configuration test failed"
    exit 1
fi

# Start Nginx
print_status "Starting Nginx..."
systemctl start nginx

if systemctl is-active --quiet nginx; then
    print_success "Nginx is running"
else
    print_error "Nginx failed to start"
    exit 1
fi

# Step 7: Get SSL certificate from Let's Encrypt
print_status "Step 7: Obtaining SSL certificate from Let's Encrypt..."

# Test HTTP access first
print_status "Testing HTTP access to Keycloak..."
if curl -s --max-time 30 http://$DOMAIN > /dev/null; then
    print_success "HTTP access is working"
else
    print_warning "HTTP access test failed, but continuing..."
fi

# Get SSL certificate
print_status "Requesting SSL certificate..."
if certbot --nginx -d $DOMAIN --non-interactive --agree-tos --email admin@$DOMAIN --redirect; then
    print_success "SSL certificate obtained successfully"
else
    print_error "Failed to obtain SSL certificate"
    print_status "Trying standalone method..."
    
    # Stop Nginx temporarily for standalone verification
    systemctl stop nginx
    if certbot certonly --standalone -d $DOMAIN --non-interactive --agree-tos --email admin@$DOMAIN; then
        print_success "SSL certificate obtained via standalone method"
        
        # Update Nginx configuration to use the certificate
        cat > /etc/nginx/sites-available/$DOMAIN << EOF
server {
    listen 80;
    server_name $DOMAIN;
    return 301 https://\$host\$request_uri;
}

server {
    listen 443 ssl http2;
    server_name $DOMAIN;
    
    ssl_certificate /etc/letsencrypt/live/$DOMAIN/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$DOMAIN/privkey.pem;
    
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-RSA-AES256-GCM-SHA512:DHE-RSA-AES256-GCM-SHA512:ECDHE-RSA-AES256-GCM-SHA384:DHE-RSA-AES256-GCM-SHA384;
    ssl_prefer_server_ciphers off;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;
    
    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header Referrer-Policy "no-referrer-when-downgrade" always;
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;

    location / {
        proxy_pass http://127.0.0.1:8080;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header X-Forwarded-Host \$host;
        proxy_set_header X-Forwarded-Port 443;
        
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
        proxy_buffering off;
        proxy_request_buffering off;
    }

    location /health {
        proxy_pass http://127.0.0.1:8080/health;
        proxy_set_header Host \$host;
        access_log off;
    }
}
EOF
        # Restart Nginx
        systemctl start nginx
    else
        print_error "Failed to obtain SSL certificate via standalone method"
        print_status "Continuing with HTTP only..."
        systemctl start nginx
    fi
fi

# Step 8: Final checks
print_status "Step 8: Performing final checks..."

# Check services
print_status "Service status:"
if systemctl is-active --quiet nginx; then
    print_success "Nginx: RUNNING"
else
    print_error "Nginx: STOPPED"
fi

if docker ps | grep -q keycloak; then
    print_success "Keycloak: RUNNING"
else
    print_error "Keycloak: STOPPED"
fi

# Check port usage
print_status "Port status:"
for port in 80 443 8080; do
    if ss -tuln | grep -q ":${port} "; then
        print_success "Port $port: LISTENING"
    else
        print_warning "Port $port: NOT LISTENING"
    fi
done

# Test HTTPS access
print_status "Testing HTTPS access..."
if curl -s -k --max-time 30 https://$DOMAIN > /dev/null; then
    print_success "HTTPS access: WORKING"
else
    print_warning "HTTPS access test failed"
fi

# Test HTTP to HTTPS redirect
print_status "Testing HTTP to HTTPS redirect..."
redirect_test=$(curl -s -I http://$DOMAIN 2>/dev/null | head -n 1 | cut -d' ' -f2)
if [ "$redirect_test" = "301" ]; then
    print_success "HTTP to HTTPS redirect: WORKING"
else
    print_warning "HTTP to HTTPS redirect: NOT WORKING"
fi

# Step 9: Create management scripts
print_status "Step 9: Creating management scripts..."

cat > /usr/local/bin/keycloak-start << 'EOF'
#!/bin/bash
cd /opt/keycloak-setup
docker-compose up -d
echo "Keycloak starting..."
sleep 10
docker ps | grep keycloak
EOF

cat > /usr/local/bin/keycloak-status << 'EOF'
#!/bin/bash
echo "=== Keycloak Container ==="
docker ps | grep keycloak || echo "Not running"
echo ""
echo "=== Services ==="
systemctl is-active nginx && echo "Nginx: RUNNING" || echo "Nginx: STOPPED"
echo ""
echo "=== SSL Certificate ==="
certbot certificates 2>/dev/null | grep -A10 "login.sourav.fun" || echo "No certificate info found"
echo ""
echo "=== Access URLs ==="
echo "Keycloak: https://login.sourav.fun"
echo "Admin:    https://login.sourav.fun/admin"
EOF

chmod +x /usr/local/bin/keycloak-*

# Step 10: Print completion message
print_success "=========================================="
print_success "🎉 KEYCLOAK SETUP COMPLETED!"
print_success "=========================================="
echo ""
echo "🌐 ACCESS URLs:"
echo "   Keycloak:       https://$DOMAIN"
echo "   Admin Console:  https://$DOMAIN/admin"
echo ""
echo "🔐 ADMIN CREDENTIALS:"
echo "   Username: $KEYCLOAK_ADMIN_USER"
echo "   Password: $KEYCLOAK_ADMIN_PASS"
echo ""
echo "🛠️  MANAGEMENT COMMANDS:"
echo "   keycloak-start   - Start Keycloak"
echo "   keycloak-status  - Check status"
echo ""
echo "📊 PORTS USED:"
echo "   Port 80:   HTTP redirect"
echo "   Port 443:  HTTPS (main access)"
echo "   Port 8080: Keycloak internal"
echo ""
print_warning "⚠️  IMPORTANT: Change the default admin password after first login!"
print_warning "⚠️  Current password: $KEYCLOAK_ADMIN_PASS"

# Save setup info
cat > /opt/keycloak-setup/setup-info.txt << EOF
Keycloak Setup Information
==========================
Domain: $DOMAIN
URL: https://$DOMAIN
Admin: https://$DOMAIN/admin

Credentials:
  Username: $KEYCLOAK_ADMIN_USER
  Password: $KEYCLOAK_ADMIN_PASS

Database:
  Host: $DB_HOST
  Port: $DB_PORT
  Name: $DB_NAME
  User: $DB_USER
  Schema: $DB_SCHEMA

Setup Date: $(date)
EOF

print_success "Setup information saved to: /opt/keycloak-setup/setup-info.txt"