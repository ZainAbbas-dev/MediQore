FROM node:24-bookworm-slim AS portal
WORKDIR /app/web
COPY web/package*.json ./
RUN npm ci
COPY web/index.html web/vite.config.mjs ./
COPY web/public ./public
COPY web/src ./src
ARG VITE_FIREBASE_API_KEY
ARG VITE_FIREBASE_PROJECT_ID
ARG VITE_FIREBASE_MESSAGING_SENDER_ID
ARG VITE_FIREBASE_APP_ID
ARG VITE_FIREBASE_VAPID_KEY
RUN npm run build

FROM node:24-bookworm-slim
RUN apt-get update \
 && apt-get install -y --no-install-recommends chromium fonts-liberation \
 && rm -rf /var/lib/apt/lists/*
WORKDIR /app
ENV NODE_ENV=production CHROME_PATH=/usr/bin/chromium CHROME_NO_SANDBOX=true PORTAL_DIR=../web/dist
COPY --chown=node:node db/package*.json ./db/
RUN npm --prefix db ci --include=dev
COPY --chown=node:node api/package*.json ./api/
RUN npm --prefix api ci --omit=dev
COPY --chown=node:node api/src ./api/src
COPY --chown=node:node db/migrations ./db/migrations
COPY --chown=node:node db/seeds ./db/seeds
COPY --chown=node:node clinical-rules/clinical-rules.json ./clinical-rules/
COPY --chown=node:node mobile/assets/fonts/JameelNooriNastaleeq.ttf ./mobile/assets/fonts/
COPY --chown=node:node --from=portal /app/web/dist ./web/dist
USER node
CMD ["sh", "-c", "npm --prefix db run migrate:up && npm --prefix db run rules:load && cd api && exec node src/server.js"]
