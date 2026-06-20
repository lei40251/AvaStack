FROM node:22-alpine AS build
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci
COPY . .
RUN npm run build

FROM node:22-alpine AS run
WORKDIR /app
RUN addgroup -S avastack && adduser -S avastack -G avastack
COPY --from=build /app/.output ./.output
COPY --from=build /app/package.json ./
USER avastack
EXPOSE 4173
ENV NODE_ENV=production
ENV PORT=4173
ENV HOST=0.0.0.0
CMD ["node", ".output/server/index.mjs"]
