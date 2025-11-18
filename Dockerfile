# Stage 1: Build the application (use Debian for Meteor compatibility)
FROM node:22.16.0-bookworm AS builder

# Install build dependencies including Deno
RUN apt-get update && apt-get install -y \
    python3 \
    make \
    g++ \
    git \
    curl \
    && curl -fsSL https://deno.land/install.sh | sh \
    && rm -rf /var/lib/apt/lists/*

# Add Deno to PATH
ENV DENO_INSTALL="/root/.deno"
ENV PATH="$DENO_INSTALL/bin:$PATH"

WORKDIR /app

# Install Meteor
RUN curl https://install.meteor.com/ | sh

# Copy everything (yarn workspaces needs all package.json files)
COPY . .

# Fix .meteor/local permissions and ensure clean build
RUN mkdir -p apps/meteor/.meteor/local && chown -R root:root apps/meteor/.meteor/local

# Enable corepack and install dependencies
RUN corepack enable && yarn install --immutable

# Build all packages first
RUN yarn build

# Build the Meteor production bundle using yarn build:ci (outputs to /tmp/dist)
RUN yarn workspace @rocket.chat/meteor run build:ci

# Stage 2: Production image
FROM node:22.16.0-alpine3.20

ENV LANG=C.UTF-8

# Install runtime dependencies
RUN apk add --no-cache shadow deno ttf-dejavu \
    && apk upgrade --no-cache openssl \
    && groupmod -n rocketchat nogroup \
    && useradd -u 65533 -r -g rocketchat rocketchat

# Set environment variables
ENV DEPLOY_METHOD=docker \
    NODE_ENV=production \
    MONGO_URL=mongodb://mongo:27017/rocketchat \
    HOME=/tmp \
    PORT=3000 \
    ROOT_URL=http://localhost:3000 \
    Accounts_AvatarStorePath=/app/uploads

WORKDIR /app

# Copy built application from builder (build:ci outputs to /tmp/dist)
COPY --from=builder --chown=rocketchat:rocketchat /tmp/dist/bundle /app/bundle

# Install production dependencies
RUN cd /app/bundle/programs/server \
    && npm install --omit=dev \
    && cd /app/bundle/programs/server/npm/node_modules/sharp \
    && npm install --omit=dev \
    && rm -rf ../@img \
    && mv node_modules/@img ../@img \
    && rm -rf node_modules

USER rocketchat

VOLUME /app/uploads

EXPOSE 3000

CMD ["node", "bundle/main.js"]
