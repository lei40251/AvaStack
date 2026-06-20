FROM node:22-alpine AS base
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci --omit=dev

FROM node:22-alpine AS build
WORKDIR /app
COPY package.json package-lock.json tsconfig.json ./
RUN npm ci
COPY src/ ./src/
RUN npm run build

FROM node:22-alpine AS run
WORKDIR /app
RUN addgroup -S avastack && adduser -S avastack -G avastack
COPY --from=base /app/node_modules ./node_modules
COPY --from=build /app/dist ./dist
COPY package.json ./
# SQLite 数据目录
RUN mkdir -p /data && chown avastack:avastack /data
USER avastack
EXPOSE 8080
ENV NODE_ENV=production
ENV DB_PATH=/data/avastack.db
CMD ["node", "dist/index.js"]
