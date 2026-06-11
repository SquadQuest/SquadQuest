# v2 backend image for Cloud Run. Bun runtime; pinned to match .tool-versions.
FROM oven/bun:1.3.14-alpine

WORKDIR /app

# Install deps first (cached layer) — needs both manifest + lockfile.
COPY package.json bun.lock ./
RUN bun install --frozen-lockfile --production

# App source + migrations (drizzle-kit migrate reads ./migrations at deploy time).
COPY . .

# Cloud Run sends traffic to $PORT (default 8080); the server reads PORT from env.
ENV PORT=8080
ENV HOST=0.0.0.0
EXPOSE 8080

CMD ["bun", "run", "src/index.ts"]
