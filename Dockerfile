# syntax=docker/dockerfile:1

ARG BUILDKIT_VERSION=v0.29.0
ARG ECR_HELPER_VERSION=v0.12.0

# Build amazon-ecr-credential-helper for the target platform on the native host.
# Uses git clone + go build so the result is independent of the Go module proxy
# and cross-compilation works reliably without a CGO toolchain.
FROM --platform=$BUILDPLATFORM golang:1.24-alpine AS ecr-builder
ARG ECR_HELPER_VERSION
ARG TARGETOS=linux
ARG TARGETARCH=amd64

RUN apk add --no-cache git ca-certificates

RUN git clone --depth 1 --branch ${ECR_HELPER_VERSION} \
    https://github.com/awslabs/amazon-ecr-credential-helper.git /src

WORKDIR /src/ecr-login
RUN CGO_ENABLED=0 GOOS=${TARGETOS} GOARCH=${TARGETARCH} \
    go build -trimpath \
    -o /out/docker-credential-ecr-login \
    ./cmd/docker-credential-ecr-login

# ── Standard (root) variant ───────────────────────────────────────────────────
FROM moby/buildkit:${BUILDKIT_VERSION} AS standard

COPY --from=ecr-builder /out/docker-credential-ecr-login /usr/local/bin/docker-credential-ecr-login

RUN mkdir -p /root/.docker && \
    printf '{"credHelpers":{"public.ecr.aws":"ecr-login","*.dkr.ecr.*.amazonaws.com":"ecr-login"}}' \
    > /root/.docker/config.json

# ── Rootless variant ──────────────────────────────────────────────────────────
FROM moby/buildkit:${BUILDKIT_VERSION}-rootless AS rootless

# Switch to root temporarily to install the binary and configure the home dir
USER root

COPY --from=ecr-builder /out/docker-credential-ecr-login /usr/local/bin/docker-credential-ecr-login

RUN mkdir -p /home/user/.docker && \
    printf '{"credHelpers":{"public.ecr.aws":"ecr-login","*.dkr.ecr.*.amazonaws.com":"ecr-login"}}' \
    > /home/user/.docker/config.json && \
    chown -R user:user /home/user/.docker

# Restore unprivileged user expected by the rootless entrypoint
USER user
