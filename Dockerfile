# syntax=docker/dockerfile:1

# Build The Lounge straight from this fork's source (the official thelounge-docker
# image installs the published npm package and so cannot run a fork).

# ---- build stage: install all deps, compile client (vite -> public/) and
#      server (tsc -> dist/), then prune dev dependencies ----
FROM node:22-alpine AS build

# git is required: a dependency (irc-framework) is pinned to a git ref
RUN apk add --no-cache git

WORKDIR /app

# Install dependencies first for better layer caching
COPY package.json yarn.lock .npmrc ./
RUN yarn install --frozen-lockfile --non-interactive

# Build from the full source tree
COPY . .
RUN NODE_ENV=production yarn build

# Drop devDependencies so the runtime image only carries what it needs
RUN yarn install --frozen-lockfile --non-interactive --production && yarn cache clean

# ---- runtime stage: minimal image, no build toolchain ----
FROM node:22-alpine AS runtime

ENV NODE_ENV=production
ENV THELOUNGE_HOME=/var/opt/thelounge

WORKDIR /app

# Copy the whole built app (source is tiny next to node_modules, and keeping it
# avoids any ambiguity about where the default config / assets are resolved at runtime)
COPY --from=build /app ./

# Data dir (config, logs, sqlite message storage, uploads) lives here
RUN install -d -o node -g node "${THELOUNGE_HOME}"
# Keep VOLUME after the dir is created so ownership sticks
VOLUME "${THELOUNGE_HOME}"

EXPOSE 9000
USER node:node

# index.js checks the node version then boots dist/server/index.js
ENTRYPOINT ["node", "index.js"]
CMD ["start"]
