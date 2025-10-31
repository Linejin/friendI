# Frontend Dockerfile - Minimal for disk space
# Build stage
FROM node:18-alpine AS build

# Set working directory
WORKDIR /app

# Install minimal build tools for alpine (much smaller)
RUN apk add --no-cache --virtual .build-deps \
    python3 \
    make \
    g++ \
    && npm config set registry https://registry.npmjs.org/

# Copy package files first for better caching
COPY package*.json ./

# Install dependencies (simplified for space)
RUN npm ci --only=production --no-audit --no-fund \
    && npm cache clean --force

# Copy source code
COPY . .

# Set environment variables for build
ENV CI=false \
    TSC_COMPILE_ON_ERROR=true \
    SKIP_PREFLIGHT_CHECK=true \
    GENERATE_SOURCEMAP=false \
    REACT_APP_ENV=production \
    NODE_OPTIONS="--max-old-space-size=2048"

# Build the application and clean up
RUN npm run build:safe \
    && npm cache clean --force \
    && apk del .build-deps \
    && rm -rf node_modules \
    && rm -rf /tmp/* /var/cache/apk/*

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