# Frontend Dockerfile
# Build stage
FROM node:18-alpine AS build

# Set working directory
WORKDIR /app

# Build arguments
ARG REACT_APP_API_URL=http://localhost:8080
ARG REACT_APP_ENV=production
ARG TSC_COMPILE_ON_ERROR=true
ARG SKIP_PREFLIGHT_CHECK=true
ARG GENERATE_SOURCEMAP=false

# Copy package files
COPY package*.json ./

# Install dependencies (including devDependencies for build)
RUN npm install

# Copy source code
COPY . .

# Set environment variables for build
ENV REACT_APP_API_URL=$REACT_APP_API_URL
ENV REACT_APP_ENV=$REACT_APP_ENV
ENV TSC_COMPILE_ON_ERROR=$TSC_COMPILE_ON_ERROR
ENV SKIP_PREFLIGHT_CHECK=$SKIP_PREFLIGHT_CHECK
ENV GENERATE_SOURCEMAP=$GENERATE_SOURCEMAP

# Build the application with error tolerance
RUN npm run build:safe

# Production stage
FROM nginx:alpine

# Copy custom nginx configuration
COPY nginx.conf /etc/nginx/nginx.conf

# Copy built application from build stage
COPY --from=build /app/build /usr/share/nginx/html

# Expose port 80
EXPOSE 80

# Start nginx
CMD ["nginx", "-g", "daemon off;"]