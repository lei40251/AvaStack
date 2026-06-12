FROM golang:1.22-alpine AS builder
WORKDIR /src
COPY go.mod ./
COPY cmd ./cmd
COPY internal ./internal
RUN go build -o /out/orchestrator ./cmd/api

FROM alpine:3.20
WORKDIR /app
COPY --from=builder /out/orchestrator /usr/local/bin/orchestrator
EXPOSE 8080
CMD ["orchestrator"]

