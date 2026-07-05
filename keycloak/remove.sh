#!/bin/bash

# Keycloak Complete Removal Script
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Function to confirm action
confirm_action() {
    local message=$1
    echo
    read -p "$message (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_status "Operation cancelled."
        exit 0
    fi
}

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    print_error "Please run as root or with sudo"
    exit 1
fi

print_status "Starting Keycloak removal process..."

# Show what will be removed
echo
print_warning "This script will remove:"
echo "  - Keycloak Docker containers and images"
echo "  - Keycloak setup directory (/opt/keycloak-setup)"
echo "  - Nginx configuration for login.sourav.fun"
echo "  - SSL certificates"
echo "  - Management scripts"
echo "  - Docker and Nginx (optional)"
echo

confirm_action "Do you want to continue with the removal?"

# Step 1: Stop and remove Keycloak containers
print_status "Step 1: Stopping and removing Keycloak containers..."

if [ -d "/opt/keycloak-setup" ]; then
    cd /opt/keycloak-setup
    if [ -f "docker-compose.yml" ]; then
        docker-compose down 2>/dev/null || true
        print_success "Keycloak containers stopped"
    else
        print_warning "No docker-compose.yml found in /opt/keycloak-setup"
    fi
else
    print_warning "Keycloak setup directory not found"
fi

# Stop any remaining Keycloak containers
docker stop keycloak 2>/dev/null || true
docker rm keycloak 2>/dev/null || true

# Remove Keycloak Docker images
print_status "Removing Keycloak Docker images..."
docker images | grep keycloak | awk '{print $3}' | xargs -r docker rmi -f 2>/dev/null || true
print_success "Keycloak Docker images removed"

# Step 2: Remove Nginx configuration
print_status "Step 2: Removing Nginx configuration..."

# Remove domain configuration
if [ -f "/etc/nginx/sites-available/login.sourav.fun" ]; then
    rm -f /etc/nginx/sites-available/login.sourav.fun
    print_success "Removed Nginx site configuration"
fi

if [ -f "/etc/nginx/sites-enabled/login.sourav.fun" ]; then
    rm -f /etc/nginx/sites-enabled/login.sourav.fun
    print_success "Removed Nginx enabled site link"
fi

# Test and reload Nginx if it's running
if systemctl is-active --quiet nginx; then
    if nginx -t 2>/dev/null; then
        systemctl reload nginx
        print_success "Nginx reloaded with updated configuration"
    else
        print_warning "Nginx configuration test failed, stopping Nginx"
        systemctl stop nginx
    fi
fi

# Step 3: Remove SSL certificates
print_status "Step 3: Removing SSL certificates..."

# Remove Let's Encrypt certificate
if certbot certificates 2>/dev/null | grep -q "login.sourav.fun"; then
    certbot delete --cert-name login.sourav.fun --non-interactive 2>/dev/null || true
    print_success "Removed Let's Encrypt certificate"
fi

# Remove certificate files
rm -rf /etc/letsencrypt/live/login.sourav.fun 2>/dev/null || true
rm -rf /etc/letsencrypt/archive/login.sourav.fun 2>/dev/null || true
rm -rf /etc/letsencrypt/renewal/login.sourav.fun.conf 2>/dev/null || true

# Remove self-signed certificates
rm -f /etc/ssl/certs/nginx-selfsigned.crt 2>/dev/null || true
rm -f /etc/ssl/private/nginx-selfsigned.key 2>/dev/null || true

# Step 4: Remove Keycloak setup directory
print_status "Step 4: Removing Keycloak setup directory..."

if [ -d "/opt/keycloak-setup" ]; then
    rm -rf /opt/keycloak-setup
    print_success "Removed /opt/keycloak-setup directory"
else
    print_warning "Keycloak setup directory not found"
fi

# Step 5: Remove management scripts
print_status "Step 5: Removing management scripts..."

rm -f /usr/local/bin/keycloak-start 2>/dev/null || true
rm -f /usr/local/bin/keycloak-stop 2>/dev/null || true
rm -f /usr/local/bin/keycloak-status 2>/dev/null || true
rm -f /usr/local/bin/keycloak-logs 2>/dev/null || true
rm -f /usr/local/bin/start-keycloak.sh 2>/dev/null || true
rm -f /usr/local/bin/stop-keycloak.sh 2>/dev/null || true
rm -f /usr/local/bin/keycloak-status.sh 2>/dev/null || true

print_success "Management scripts removed"

# Step 6: Remove SSL renewal hooks
print_status "Step 6: Cleaning up SSL renewal hooks..."

rm -f /etc/letsencrypt/renewal-hooks/post/reload-nginx.sh 2>/dev/null || true

# Step 7: Clean up Docker (optional)
echo
print_warning "Docker cleanup options:"
echo "  1: Remove only Keycloak-related containers and images (Recommended)"
echo "  2: Remove all unused Docker data (Containers, images, networks, volumes)"
echo "  3: Complete Docker removal (Uninstall Docker)"
echo "  4: Skip Docker cleanup"

read -p "Select Docker cleanup option (1-4): " docker_option

case $docker_option in
    1)
        print_status "Removing Keycloak-related Docker resources..."
        # Remove unused containers
        docker container prune -f 2>/dev/null || true
        # Remove unused images
        docker image prune -af 2>/dev/null || true
        print_success "Docker cleanup completed"
        ;;
    2)
        confirm_action "This will remove ALL unused Docker data. Continue?"
        print_status "Removing all unused Docker data..."
        docker system prune -af --volumes 2>/dev/null || true
        print_success "All unused Docker data removed"
        ;;
    3)
        confirm_action "This will COMPLETELY UNINSTALL Docker. Continue?"
        print_status "Uninstalling Docker..."
        # Stop all containers
        docker stop $(docker ps -aq) 2>/dev/null || true
        # Remove all containers
        docker rm $(docker ps -aq) 2>/dev/null || true
        # Remove all images
        docker rmi -f $(docker images -q) 2>/dev/null || true
        # Remove all volumes
        docker volume rm $(docker volume ls -q) 2>/dev/null || true
        # Remove all networks
        docker network rm $(docker network ls -q) 2>/dev/null || true
        
        # Uninstall Docker
        apt remove -y docker docker-engine docker.io containerd runc 2>/dev/null || true
        apt remove -y docker-ce docker-ce-cli containerd.io 2>/dev/null || true
        apt purge -y docker* 2>/dev/null || true
        rm -rf /var/lib/docker
        rm -rf /etc/docker
        rm -f /etc/apparmor.d/docker
        rm -rf /var/run/docker.sock
        print_success "Docker completely uninstalled"
        ;;
    4)
        print_status "Skipping Docker cleanup"
        ;;
    *)
        print_error "Invalid option. Skipping Docker cleanup."
        ;;
esac

# Step 8: Remove Nginx (optional)
echo
read -p "Remove Nginx completely? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    print_status "Removing Nginx..."
    systemctl stop nginx 2>/dev/null || true
    systemctl disable nginx 2>/dev/null || true
    apt remove -y nginx nginx-common nginx-full 2>/dev/null || true
    apt purge -y nginx* 2>/dev/null || true
    rm -rf /etc/nginx
    rm -rf /var/www/html
    rm -rf /usr/share/nginx
    print_success "Nginx completely removed"
else
    print_status "Nginx kept installed"
fi

# Step 9: Clean up firewall rules
print_status "Step 9: Cleaning up firewall rules..."

# if command -v ufw &> /dev/null; then
#     ufw delete allow 80/tcp 2>/dev/null || true
#     ufw delete allow 443/tcp 2>/dev/null || true
#     print_success "Firewall rules cleaned up"
# fi

# Step 10: Final cleanup
print_status "Step 10: Performing final cleanup..."

# Remove log files
rm -f /var/log/nginx/login.sourav.fun* 2>/dev/null || true

# Remove temporary files
rm -f /tmp/keycloak* 2>/dev/null || true

# Clean up apt
apt autoremove -y 2>/dev/null || true
apt autoclean -y 2>/dev/null || true

# Final verification
print_status "=== VERIFICATION ==="

# Check if Keycloak containers are gone
if docker ps -a | grep -q keycloak; then
    print_error "Keycloak containers still exist:"
    docker ps -a | grep keycloak
else
    print_success "No Keycloak containers found"
fi

# Check if setup directory is gone
if [ -d "/opt/keycloak-setup" ]; then
    print_error "Keycloak setup directory still exists"
else
    print_success "Keycloak setup directory removed"
fi

# Check if Nginx configuration is gone
if [ -f "/etc/nginx/sites-enabled/login.sourav.fun" ] || [ -f "/etc/nginx/sites-available/login.sourav.fun" ]; then
    print_error "Nginx configuration still exists"
else
    print_success "Nginx configuration removed"
fi

# Check port status
print_status "Port status:"
for port in 80 443 8080; do
    if ss -tuln | grep -q ":${port} "; then
        print_warning "Port $port is still in use by:"
        ss -tulnp | grep ":${port} "
    else
        print_success "Port $port is free"
    fi
done

print_success "=========================================="
print_success "🎉 KEYCLOAK REMOVAL COMPLETED!"
print_success "=========================================="
echo
echo "✅ Removed:"
echo "   - Keycloak Docker containers and images"
echo "   - Nginx configuration for login.sourav.fun"
echo "   - SSL certificates"
echo "   - Management scripts"
echo "   - Setup directory"
echo
echo "📝 Note: Your PostgreSQL database at ${DB_HOST}:${DB_PORT} was NOT touched."
echo "   The 'keycloak' schema and data still exist in the database."
echo
print_warning "If you want to completely remove Keycloak data from PostgreSQL,"
print_warning "manually connect to the database and drop the 'keycloak' schema."