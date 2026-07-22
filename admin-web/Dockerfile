# Yonetio admin-web — uretim imaji (Next.js standalone).
# BFF (sunucu tarafi) API'ye ic agdan (http://api:8000) baglanir; API_BASE_URL
# calisma zamaninda docker-compose.prod.yml'den verilir (imaj yeniden derlenmez).

# --- deps: tam bagimliliklar (dev dahil; `next build` typescript'e ihtiyac duyar)
FROM node:20-alpine AS deps
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci

# --- builder: standalone ciktisi uret
FROM node:20-alpine AS builder
WORKDIR /app
ENV NEXT_TELEMETRY_DISABLED=1
COPY --from=deps /app/node_modules ./node_modules
COPY . .
RUN npm run build

# --- runner: minimal calisma-zamani (yalniz standalone server + statik varliklar)
FROM node:20-alpine AS runner
WORKDIR /app
ENV NODE_ENV=production \
    NEXT_TELEMETRY_DISABLED=1 \
    PORT=3000 \
    HOSTNAME=0.0.0.0
RUN addgroup -g 1001 -S nodejs && adduser -S nextjs -u 1001
COPY --from=builder /app/public ./public
COPY --from=builder --chown=nextjs:nodejs /app/.next/standalone ./
COPY --from=builder --chown=nextjs:nodejs /app/.next/static ./.next/static
USER nextjs
EXPOSE 3000
CMD ["node", "server.js"]
