FROM node:22-alpine AS base
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci --omit=dev --no-audit --no-fund --loglevel=error

FROM node:22-alpine AS run
WORKDIR /app
RUN addgroup -S avastack && adduser -S avastack -G avastack
COPY --from=base /app/node_modules ./node_modules
COPY package.json tsconfig.json ./
COPY src/ ./src/
RUN mkdir -p /data && chown avastack:avastack /data
# 安装 tsx 用于生产运行（Hono tsx 兼容性优于 tsc）
RUN npm install tsx --no-audit --no-fund --loglevel=error
USER avastack
EXPOSE 8080
ENV NODE_ENV=production
ENV DB_PATH=/data/avastack.db
CMD ["npx", "tsx", "src/index.ts"]
