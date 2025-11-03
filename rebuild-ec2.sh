#!/bin/bash

# EC2 Container Rebuild Script - Fix Configuration Issues
# Run this on EC2 to rebuild containers with fixed configurations

echo "🔧 Rebuilding FriendlyI containers with fixed configurations..."

# Stop existing containers
echo "Stopping existing containers..."
sudo docker-compose -f docker-compose.minimal.yml down --remove-orphans

# Remove existing images to force rebuild
echo "Removing old images..."
sudo docker rmi $(sudo docker images -f "dangling=true" -q) 2>/dev/null || true
sudo docker system prune -f

# Rebuild and start containers
echo "Rebuilding containers..."
sudo docker-compose -f docker-compose.minimal.yml build --no-cache

echo "Starting containers..."
sudo docker-compose -f docker-compose.minimal.yml up -d

# Wait for containers to start
echo "Waiting for containers to start..."
sleep 30

# Check container status
echo "Container status:"
sudo docker ps

echo "Health check:"
sudo docker-compose -f docker-compose.minimal.yml ps

# Show logs for debugging
echo "Backend logs:"
sudo docker logs friendlyi-backend-minimal --tail 20

echo "Frontend logs:"
sudo docker logs friendlyi-frontend-minimal --tail 20

echo "✅ Rebuild complete! Check the logs above for any issues."
echo "Access your application at:"
echo "  Frontend: http://your-ec2-ip:3000"
echo "  Backend API: http://your-ec2-ip:8080/api"