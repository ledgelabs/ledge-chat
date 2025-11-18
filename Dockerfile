# Stage 1: Build the application
FROM node:22.16.0-alpine3.20 AS builder

# Install build dependencies including Deno
RUN apk add --no-cache python3 make g++ py3-setuptools libc6-compat git deno

WORKDIR /app

# Copy everything (yarn workspaces needs all package.json files)
COPY . .

# Enable corepack and install dependencies
RUN corepack enable && yarn install --immutable

# Build the application
ENV NODE_ENV=production
RUN yarn build

# Build the Meteor production bundle
RUN cd apps/meteor && \
    METEOR_DISABLE_OPTIMISTIC_CACHING=1 meteor build --server-only --directory /tmp/build

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

# Copy built application from builder
COPY --from=builder --chown=rocketchat:rocketchat /tmp/build/bundle /app/bundle

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
