# syntax=docker/dockerfile:1
# Build context is the repository root: the image also needs the Rails evaluator.

FROM golang:1.27-alpine AS build
WORKDIR /src
COPY services/sandboxd/ ./
RUN go test ./... && CGO_ENABLED=0 go build -trimpath -ldflags="-s -w" -o /out/sandboxd .

FROM ruby:4.0-alpine
RUN adduser -D -u 10001 sandbox
COPY --from=build /out/sandboxd /usr/local/bin/sandboxd
COPY backend/app/domains/playground/evaluator.rb /opt/sandbox/evaluator.rb
USER sandbox
ENV SANDBOX_ADDR=:8080 \
    SANDBOX_EVALUATOR=/opt/sandbox/evaluator.rb
EXPOSE 8080
ENTRYPOINT ["sandboxd"]
