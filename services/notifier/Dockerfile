# syntax=docker/dockerfile:1
FROM golang:1.27-alpine AS build
WORKDIR /src
COPY services/notifier/go.mod services/notifier/go.sum ./
RUN go mod download
COPY services/notifier/ ./
RUN go test ./... && CGO_ENABLED=0 go build -trimpath -ldflags="-s -w" -o /out/notifier .

FROM alpine:3.22
RUN apk add --no-cache ca-certificates && adduser -D -u 10003 notifier
COPY --from=build /out/notifier /usr/local/bin/notifier
USER notifier
ENTRYPOINT ["notifier"]
