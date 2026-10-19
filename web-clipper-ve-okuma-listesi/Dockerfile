FROM node:22-alpine
WORKDIR /app
RUN apk add --no-cache openssl

COPY package.json package-lock.json ./
RUN npm ci

COPY . .
ENV DATABASE_URL="file:/data/dev.db"
ENV NEXT_TELEMETRY_DISABLED=1

RUN npx prisma generate && npm run build

RUN mkdir -p /data
VOLUME ["/data"]

EXPOSE 3000
ENV PORT=3000
ENV HOSTNAME="0.0.0.0"

CMD ["sh", "-c", "npx prisma db push && npm start"]
