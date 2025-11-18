# =============================================================================
# SkyFi MCP - Production Dockerfile (Multi-stage Build)
# Optimized for Fly.io deployment with SQLite3
# =============================================================================

# -----------------------------------------------------------------------------
# Stage 1: Build
# -----------------------------------------------------------------------------
FROM hexpm/elixir:1.16.0-erlang-26.2.1-alpine-3.19.0 AS build

# Install build dependencies
RUN apk add --no-cache \
    build-base \
    git \
    sqlite-dev

# Set build environment
ENV MIX_ENV=prod

# Create app directory
WORKDIR /app

# Install hex and rebar
RUN mix local.hex --force && \
    mix local.rebar --force

# Copy dependency files
COPY mix.exs mix.lock ./

# Install production dependencies
RUN mix deps.get --only prod && \
    mix deps.compile

# Copy application code
COPY config ./config
COPY lib ./lib
COPY priv ./priv

# Compile the application
RUN mix compile

# Build the release
RUN mix release

# -----------------------------------------------------------------------------
# Stage 2: Runtime
# -----------------------------------------------------------------------------
FROM alpine:3.19.0 AS app

# Install runtime dependencies
RUN apk add --no-cache \
    libstdc++ \
    openssl \
    ncurses-libs \
    sqlite-libs \
    sqlite

# Create app user
RUN addgroup -g 1000 skyfi && \
    adduser -D -u 1000 -G skyfi skyfi

# Create app directory
WORKDIR /app

# Create data directory for SQLite database
RUN mkdir -p /data && \
    chown -R skyfi:skyfi /data

# Copy the release from build stage
COPY --from=build --chown=skyfi:skyfi /app/_build/prod/rel/skyfi_mcp ./

# Switch to app user
USER skyfi

# Set environment variables
ENV HOME=/app
ENV MIX_ENV=prod
ENV DATA=/data
ENV PORT=8080
ENV PHX_SERVER=true

# Expose port
EXPOSE 8080

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=40s --retries=3 \
  CMD ["/bin/sh", "-c", "wget -q --spider http://localhost:8080/health || exit 1"]

# Start the application
CMD ["/app/bin/skyfi_mcp", "start"]
