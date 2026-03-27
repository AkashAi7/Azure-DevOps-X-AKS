# syntax=docker/dockerfile:1
# ─────────────────────── Stage 1: Build ────────────────────────────────────
FROM node:20-alpine AS builder

WORKDIR /app

# Copy dependency files first (layer caching)
COPY package*.json ./

# Install all dependencies (including dev for build step)
RUN npm ci --frozen-lockfile

# Copy source code
COPY src/ ./src/

# ─────────────────────── Stage 2: Production ───────────────────────────────
FROM node:20-alpine AS production

# Add non-root user for security
RUN addgroup -S appgroup && adduser -S appuser -G appgroup

WORKDIR /app

# Copy only production dependencies
COPY package*.json ./
RUN npm ci --only=production --frozen-lockfile && npm cache clean --force

# Copy application source
COPY --from=builder /app/src ./src

# Set ownership
RUN chown -R appuser:appgroup /app

# Switch to non-root user
USER appuser

# Environment defaults (override at runtime)
ENV NODE_ENV=production
ENV PORT=3000
ENV APP_VERSION=1.0.0
ENV ENVIRONMENT=production

EXPOSE 3000

# Health check
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:3000/health || exit 1

CMD ["node", "src/app.js"]
