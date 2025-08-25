#!/bin/bash

# SOILDATA Deployment Script
# ==========================

set -e

echo "🌱 Starting SOILDATA Dataverse Deployment..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running as root
if [ "$EUID" -eq 0 ]; then
    print_warning "Running as root. Consider running as non-root user for security."
fi

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    print_error "Docker is not installed. Please install Docker first."
    exit 1
fi

# Check if Docker Compose is installed
if ! command -v docker-compose &> /dev/null; then
    print_error "Docker Compose is not installed. Please install Docker Compose first."
    exit 1
fi

# Check if .env file exists
if [ ! -f ".env" ]; then
    print_error ".env file not found. Please configure your environment variables first."
    print_warning "Copy .env_sample to .env and edit it with your production settings."
    exit 1
fi

# Create necessary directories
print_status "Creating necessary directories..."
mkdir -p database-data minio-data letsencrypt data docroot

# Set proper permissions
print_status "Setting proper permissions..."
chmod 600 secrets/admin/password secrets/api/key secrets/db/password secrets/doi/password
chmod -R 755 init.d
chmod +x init.d/*.sh

# Create Docker network if it doesn't exist
print_status "Creating Docker network 'traefik'..."
docker network create traefik 2>/dev/null || print_warning "Network 'traefik' already exists"

# Load environment variables
source .env

# Validate critical environment variables
if [ -z "$traefikhost" ]; then
    print_error "traefikhost is not set in .env file"
    exit 1
fi

if [ -z "$useremail" ]; then
    print_error "useremail is not set in .env file"
    exit 1
fi

# Pre-deployment checks
print_status "Running pre-deployment checks..."

# Check if domain is accessible (optional, for production)
if [ "$traefikhost" != "localhost" ] && [ "$traefikhost" != "localhost:8080" ]; then
    print_status "Checking domain accessibility for $traefikhost..."
    if ! ping -c 1 "$traefikhost" &> /dev/null; then
        print_warning "Domain $traefikhost is not reachable. Make sure DNS is configured properly."
    fi
fi

# Stop existing containers if they exist
print_status "Stopping existing containers..."
docker-compose down 2>/dev/null || true

# Pull latest images
print_status "Pulling latest Docker images..."
docker-compose pull

# Start the services
print_status "Starting SOILDATA services..."
docker-compose up -d

# Wait for services to be ready
print_status "Waiting for services to start..."
sleep 30

# Check if services are running
print_status "Checking service status..."
if docker-compose ps | grep -q "Up"; then
    print_success "Services are starting up..."
    
    # Show running containers
    echo ""
    print_status "Running containers:"
    docker-compose ps
    
    echo ""
    print_success "SOILDATA deployment initiated successfully!"
    echo ""
    print_status "🌐 Access your SOILDATA instance at:"
    if [ "$traefikhost" = "localhost" ] || [ "$traefikhost" = "localhost:8080" ]; then
        print_status "   http://localhost:8080"
    else
        print_status "   https://$traefikhost"
    fi
    echo ""
    print_status "📊 Admin interfaces:"
    print_status "   Traefik: http://localhost:8089"
    print_status "   Solr: https://solr.$traefikhost"
    print_status "   MinIO: https://minio-console.$traefikhost"
    echo ""
    print_status "🔐 Default admin credentials:"
    print_status "   Username: dataverseAdmin"
    print_status "   Password: $(cat secrets/admin/password)"
    echo ""
    print_warning "⚠️  IMPORTANT: Change default passwords in production!"
    print_warning "⚠️  Configure DOI, SMTP, and other production settings in .env"
    echo ""
    print_status "📋 Next steps:"
    print_status "   1. Wait 2-5 minutes for full initialization"
    print_status "   2. Access the web interface and change admin password"
    print_status "   3. Configure your dataverse settings"
    print_status "   4. Set up backup procedures"
    print_status "   5. Configure monitoring"
    echo ""
    print_status "📝 View logs with: docker-compose logs -f"
    
else
    print_error "Some services failed to start. Check logs with: docker-compose logs"
    exit 1
fi