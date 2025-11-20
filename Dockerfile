# Rocket.Chat Docker image for pre-built bundle
# Using Node 22.16.0 for Yarn v4 compatibility and package.json requirements
FROM node:22.16.0-bookworm-slim

ENV LANG=C.UTF-8

# Install runtime dependencies (build tools for native modules)
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        fontconfig \
        curl \
        unzip \
        python3 \
        make \
        g++ \
        libssl-dev \
        graphicsmagick \
    && curl -fsSL https://deno.land/install.sh | sh \
    && corepack enable \
    && npm install -g npm@10.9.2 \
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
# Patch npm-rebuild.js to use absolute path to npm, then install
RUN cd /app/bundle/programs/server \
    && sed -i "s/spawn('npm'/spawn('\/usr\/local\/bin\/npm'/g" npm-rebuild.js \
    && npm install --omit=dev --unsafe-perm=true \
    && chown -R rocketchat:rocketchat /app

USER rocketchat

VOLUME /app/uploads

EXPOSE 3000

WORKDIR /app/bundle

CMD ["node", "main.js"]
