# ---- Stage 1: install production dependencies ----
FROM node:22-slim AS deps
WORKDIR /app

# Copy only the manifest files first, so this layer is cached
# and only rebuilds when dependencies actually change.
COPY package.json package-lock.json ./

# Install exactly what the lockfile pins, nothing else, and only
# production dependencies. npm ci is stricter and more reproducible
# than npm install: it fails if package.json and the lockfile disagree.
RUN npm ci --omit=dev

# ---- Stage 2: the runtime image ----
FROM node:22-slim AS runtime
WORKDIR /app

# Run as a non-root user. The node image ships one called "node".
# A container that runs as root is a container escape away from
# root on the host; dropping privileges is basic hardening.
ENV NODE_ENV=production

# Bring in the installed dependencies from the deps stage.
COPY --from=deps /app/node_modules ./node_modules

# Copy the application source.
COPY package.json package-lock.json ./
COPY src ./src

# Drop to the unprivileged user for everything that follows.
USER node

# Document the port the app listens on.
EXPOSE 3000

# Start the app.
CMD ["node", "src/app.js"]
