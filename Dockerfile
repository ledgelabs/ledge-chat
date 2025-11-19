# Rocket.Chat Docker image for pre-built bundle
# This Dockerfile expects the bundle to be pre-built by GitHub Actions
# Using Debian like the official release for better compatibility
FROM node:22.16.0-bookworm-slim

ENV LANG=C.UTF-8

# Install runtime dependencies
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        fontconfig \
        curl \
        unzip \
    && curl -fsSL https://deno.land/install.sh | sh \
    && groupadd -r rocketchat \
    && useradd -r -g rocketchat -u 65533 rocketchat \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Add Deno to PATH
ENV DENO_INSTALL="/root/.deno"
ENV PATH="$DENO_INSTALL/bin:$PATH"

# Set default environment variables (overridden by ECS task definition)
ENV DEPLOY_METHOD=docker \
    NODE_ENV=production \
    MONGO_URL=mongodb://mongo:27017/rocketchat \
    HOME=/tmp \
    PORT=3000 \
    ROOT_URL=http://localhost:3000 \
    Accounts_AvatarStorePath=/app/uploads

WORKDIR /app

# Copy the pre-built bundle from GitHub Actions build (copied to docker-build/ by workflow)
COPY docker-build/bundle /app/bundle

# Install production npm dependencies
RUN cd /app/bundle/programs/server \
    && npm install --omit=dev --unsafe-perm \
    && chown -R rocketchat:rocketchat /app

USER rocketchat

VOLUME /app/uploads

EXPOSE 3000

WORKDIR /app/bundle

CMD ["node", "main.js"]
