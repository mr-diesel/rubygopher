# syntax=docker/dockerfile:1
FROM golang:1.27-alpine AS build
WORKDIR /src
COPY services/fetcher/go.mod services/fetcher/go.sum ./
RUN go mod download
COPY services/fetcher/ ./
RUN go test ./... && CGO_ENABLED=0 go build -trimpath -ldflags="-s -w" -o /out/fetcher .

FROM alpine:3.22
RUN apk add --no-cache ca-certificates && adduser -D -u 10002 fetcher
COPY --from=build /out/fetcher /usr/local/bin/fetcher
USER fetcher
ENTRYPOINT ["fetcher"]
