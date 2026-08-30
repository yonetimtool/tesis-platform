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
# (P191 §1) KONAK-OTESI YONLENDIRME HEDEFI DERLEME ANINDA GOMULUR.
#
# `middleware.ts` edge calisma zamaninda kosar; orada `process.env` derleme
# aninda degistirilir, calisma zamaninda okunmaz. Bu yuzden kanonik `app.*`
# kok adresi build arg olarak gecilir. VERILMEZSE davranis bozulmaz:
# middleware iletilmis basliklardan (`x-forwarded-host`) turetir — yine
# portsuz ve https. Bkz. lib/konak-adres.ts.
ARG NEXT_PUBLIC_APP_ADRESI=""
ENV NEXT_PUBLIC_APP_ADRESI=$NEXT_PUBLIC_APP_ADRESI
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
