# Build stage
FROM hexpm/elixir:1.17.0-erlang-27.0-debian-bookworm-20240701-slim AS builder

# Install build dependencies
RUN apt-get update -y && apt-get install -y \
    build-essential \
    git \
    curl \
    && apt-get clean && rm -f /var/lib/apt/lists/*_*

# Set working directory
WORKDIR /app

# Install hex + rebar
RUN mix local.hex --force && \
    mix local.rebar --force

# Set build ENV
ENV MIX_ENV=prod

# Install mix dependencies
COPY mix.exs mix.lock ./
RUN mix deps.get --only prod
RUN mix deps.compile

# Copy compile-time config files before compiling
COPY config/config.exs config/prod.exs config/
RUN mix compile

# Copy priv at build time
COPY priv priv

# Copy lib files for compilation
COPY lib lib

# Compile the project
RUN mix compile

# Build assets (if any)
COPY assets assets
RUN mix assets.deploy || true

# Build release
RUN mix release

# Runtime stage
FROM debian:bookworm-20240701-slim AS app

# Install runtime dependencies
RUN apt-get update -y && apt-get install -y \
    libstdc++6 \
    openssl \
    libncurses5 \
    locales \
    ca-certificates \
    && apt-get clean && rm -f /var/lib/apt/lists/*_*

# Set locale
RUN sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen
ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US:en
ENV LC_ALL=en_US.UTF-8

# Create app user
RUN useradd -m -u 1000 -s /bin/bash app
USER app
WORKDIR /home/app

# Copy the release from builder
COPY --from=builder --chown=app:app /app/_build/prod/rel/feedback_bot ./

# Set environment
ENV MIX_ENV=prod
ENV PORT=8080

# Expose port
EXPOSE 8080

# Start the application
CMD ["bin/feedback_bot", "start"]
