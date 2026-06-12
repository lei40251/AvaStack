FROM node:22-alpine
WORKDIR /app
COPY package.json tsconfig.json index.html ./
COPY src ./src
RUN npm install
EXPOSE 4173
CMD ["sh", "-c", "printf 'window.__ORCHESTRATOR_BASE_URL__ = \"%s\";\\n' \"$ORCHESTRATOR_BASE_URL\" > /app/src/runtime-config.js && npm run dev -- --host 0.0.0.0 --port 4173"]
