# Frontend Dockerfile - Simplified and Optimized
# Build stage
FROM node:18-alpine AS build

# Set working directory
WORKDIR /app

# Install system dependencies for native modules
RUN apk add --no-cache python3 make g++

# Set npm configuration for better reliability
RUN npm config set registry https://registry.npmjs.org/ && \
    npm config set fetch-retry-mintimeout 20000 && \
    npm config set fetch-retry-maxtimeout 120000 && \
    npm config set fetch-retries 5

# Copy package files first for better caching
COPY package*.json ./

# Install dependencies with error handling and memory optimization
RUN npm config set maxsockets 1 && \
    npm config set registry https://registry.npmjs.org/ && \
    (npm ci --no-optional --prefer-offline || npm install --no-optional --prefer-offline)

# Copy source code
COPY . .

# Set environment variables for build
ENV CI=false
ENV TSC_COMPILE_ON_ERROR=true
ENV SKIP_PREFLIGHT_CHECK=true
ENV GENERATE_SOURCEMAP=false
ENV REACT_APP_ENV=production
ENV REACT_APP_API_BASE_URL=/api
ENV REACT_APP_API_TIMEOUT=10000

# Build the application with memory optimization
RUN export NODE_OPTIONS="--max-old-space-size=512" && npm run build:safe

# Production stage with nginx
FROM nginx:alpine

# Remove default nginx config
RUN rm /etc/nginx/conf.d/default.conf

# Copy custom nginx configuration
COPY nginx.conf /etc/nginx/nginx.conf

# Copy built application from build stage
COPY --from=build /app/build /usr/share/nginx/html

# Create nginx directories if they don't exist
RUN mkdir -p /var/log/nginx && \
    mkdir -p /var/cache/nginx && \
    mkdir -p /var/run && \
    touch /var/run/nginx.pid && \
    chown -R nginx:nginx /var/log/nginx /var/cache/nginx /var/run/nginx.pid

# Expose port 80
EXPOSE 80

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD curl -f http://localhost/ || exit 1

# Start nginx in foreground
CMD ["nginx", "-g", "daemon off;"]