FROM node:20-alpine AS deps
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci

FROM deps AS builder
COPY tsconfig.json ./
COPY src/ src/
RUN npm run build

FROM node:20-alpine AS prod-deps
WORKDIR /app
ENV NODE_ENV=production
COPY package.json package-lock.json ./
RUN npm ci --omit=dev

FROM node:20-alpine
WORKDIR /app
ENV NODE_ENV=production
COPY --from=builder /app/dist dist/
COPY --from=prod-deps /app/node_modules node_modules/
COPY package.json ./
RUN mkdir -p /data /config && chown -R node:node /app /data /config
EXPOSE 8317
VOLUME ["/data", "/config"]
USER node
CMD ["node", "dist/index.js", "--config=/config/config.yaml"]
