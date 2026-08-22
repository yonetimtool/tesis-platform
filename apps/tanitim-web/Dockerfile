# Yonetiyor tanitim-web — uretim imaji (Next.js standalone).
#
# admin-web'in Dockerfile'i ile AYNI YAPI ve bu bilincli: iki Next
# uygulamasinin ayni depoda farkli yapim desenleriyle derlenmesi, bir gun
# birinde duzeltilen bir sorunun otekinde durmasi demekti.
#
# TEK FARK: bu imajin CALISMA ZAMANI ORTAM DEGISKENI YOKTUR. Sitedeki
# `NEXT_PUBLIC_*` degerleri DERLEME ANINDA gomulur; bu yuzden bayrak
# degistirmek imaji yeniden derlemeyi gerektirir (bkz. docs/P177-dagitim.md).
# `API_BASE_URL` bunun DISINDADIR: sunucu tarafi (BFF) onu calisma
# aninda okur, compose'tan gelir.

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
# NEXT_PUBLIC_* bayraklari derleme argumani olarak gelir; verilmezse
# `config/site.ts`teki varsayilanlar (test kurulumu) gecerlidir.
ARG NEXT_PUBLIC_APP_ADRESI
ARG NEXT_PUBLIC_SITE_ADRESI
ARG NEXT_PUBLIC_PLAY_ADRESI
ARG NEXT_PUBLIC_APP_STORE_ADRESI
ARG NEXT_PUBLIC_ILETISIM_EPOSTA
ARG NEXT_PUBLIC_TANITIM_UCRETSIZ
ARG NEXT_PUBLIC_SSO_GOOGLE
ARG NEXT_PUBLIC_SSO_MICROSOFT
ARG NEXT_PUBLIC_SSO_APPLE
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
