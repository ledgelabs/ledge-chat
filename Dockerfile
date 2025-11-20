# Rocket.Chat single-stage build - build everything inside Docker
FROM node:22.16.0-bookworm

ENV LANG=C.UTF-8

# Install build dependencies
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
        git \
    && curl -fsSL https://deno.land/install.sh | sh \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Download AWS DocumentDB CA certificate
RUN curl -fsSL https://truststore.pki.rds.amazonaws.com/global/global-bundle.pem -o /usr/local/share/rds-combined-ca-bundle.pem

# Add Deno to PATH and configure Node.js to trust DocumentDB CA
ENV DENO_INSTALL="/root/.deno"
ENV PATH="$DENO_INSTALL/bin:$PATH"
ENV NODE_EXTRA_CA_CERTS="/usr/local/share/rds-combined-ca-bundle.pem"

# Install Meteor
RUN curl https://install.meteor.com/ | sed s/--progress-bar/-sL/g | /bin/sh

# Set working directory
WORKDIR /app

# Copy source code
COPY . /app

# Install dependencies and build
RUN corepack enable \
    && yarn install \
    && yarn build

# Build Meteor bundle
ENV METEOR_ALLOW_SUPERUSER=1 \
    METEOR_PROFILE=1000 \
    BABEL_ENV=production

RUN yarn workspace @rocket.chat/meteor run build:ci

# Move bundle to final location
RUN mv /tmp/dist/bundle /app/bundle

# Install production dependencies in the bundle
RUN cd /app/bundle/programs/server \
    && npm install --omit=dev --unsafe-perm=true

# Create rocketchat user
RUN groupadd -r rocketchat \
    && useradd -r -g rocketchat -u 65533 rocketchat \
    && chown -R rocketchat:rocketchat /app/bundle

# Set default environment variables
ENV DEPLOY_METHOD=docker \
    NODE_ENV=production \
    MONGO_URL=mongodb://mongo:27017/rocketchat \
    HOME=/tmp \
    PORT=3000 \
    ROOT_URL=http://localhost:3000 \
    Accounts_AvatarStorePath=/app/uploads

USER rocketchat

WORKDIR /app/bundle

VOLUME /app/uploads

EXPOSE 3000

CMD ["node", "main.js"]
