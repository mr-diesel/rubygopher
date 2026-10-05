# syntax=docker/dockerfile:1
# Build context is the repository root. The Rails app and its gems are not baked in:
# compose mounts ./backend and the gem volume read-only, so the image only needs the
# same Ruby and system libraries as the backend image.

ARG RUBY_VERSION=4.0.7

FROM golang:1.27-alpine AS build
WORKDIR /src
COPY services/sandboxd/ ./
RUN go test ./... && CGO_ENABLED=0 go build -trimpath -ldflags="-s -w" -o /out/sandboxd .

FROM ruby:${RUBY_VERSION}-slim
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y libpq5 libvips libyaml-0-2 && \
    rm -rf /var/lib/apt/lists/* && \
    gem install bundler && \
    useradd --uid 10001 --create-home --shell /usr/sbin/nologin sandbox
COPY --from=build /out/sandboxd /usr/local/bin/sandboxd
USER sandbox
ENV SANDBOX_ADDR=:8080 \
    BUNDLE_PATH=/usr/local/bundle
EXPOSE 8080
ENTRYPOINT ["sandboxd"]
