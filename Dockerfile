# Rocket.Chat Docker image for pre-built bundle
# This Dockerfile expects the bundle to be pre-built by GitHub Actions at /tmp/dist/bundle
FROM node:22.16.0-alpine3.20

ENV LANG=C.UTF-8

# Install runtime and build dependencies
RUN apk add --no-cache \
    ca-certificates \
    fontconfig \
    shadow \
    deno \
    ttf-dejavu \
    # Build tools needed for npm install (native modules)
    python3 \
    make \
    g++ \
    && apk upgrade --no-cache openssl \
    && groupmod -n rocketchat nogroup \
    && useradd -u 65533 -r -g rocketchat rocketchat

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

# Install production npm dependencies (as root, then chown)
RUN cd /app/bundle/programs/server \
    && npm install --omit=dev \
    && cd /app/bundle/programs/server/npm/node_modules/sharp \
    && npm install --omit=dev \
    && rm -rf ../@img \
    && mv node_modules/@img ../@img \
    && rm -rf node_modules \
    # Remove build tools to reduce image size
    && apk del python3 make g++ \
    # Set ownership after build
    && chown -R rocketchat:rocketchat /app

USER rocketchat

VOLUME /app/uploads

EXPOSE 3000

WORKDIR /app/bundle

CMD ["node", "main.js"]
