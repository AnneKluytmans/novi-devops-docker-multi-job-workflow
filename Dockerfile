# Stage 1: Build
FROM node:20-alpine AS builder

WORKDIR /app

# Kopieer package files
COPY package*.json ./

# Installeer alle dependencies (inclusief devDependencies voor build)
RUN npm ci

# Kopieer source code
COPY . .

# Stage 2: Production
FROM node:20-alpine

WORKDIR /app

# Kopieer package files
COPY package*.json ./

# Installeer alleen production dependencies
RUN npm ci --only=production

# Kopieer source code (geen tests nodig in productie)
COPY src ./src/

# Maak non-root user voor security
RUN addgroup -g 1001 -S nodejs && \
    adduser -S nodejs -u 1001 -G nodejs

USER nodejs

# Expose de poort - Render gebruikt PORT 10000
EXPOSE 10000

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:3000/health || exit 1

# Start de applicatie
CMD ["node", "src/index.js"]
