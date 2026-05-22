# syntax=docker/dockerfile:1

ARG BUILDKIT_VERSION=v0.21.0
ARG ECR_HELPER_VERSION=v0.10.0

# Build amazon-ecr-credential-helper for the target platform on the native host
FROM --platform=$BUILDPLATFORM golang:1.24-alpine AS ecr-builder
ARG ECR_HELPER_VERSION
ARG TARGETOS
ARG TARGETARCH

RUN apk add --no-cache git ca-certificates

RUN GOOS=${TARGETOS} GOARCH=${TARGETARCH} \
    go install github.com/awslabs/amazon-ecr-credential-helper/ecr-login/cmd/docker-credential-ecr-login@${ECR_HELPER_VERSION}

# ── Standard (root) variant ───────────────────────────────────────────────────
FROM moby/buildkit:${BUILDKIT_VERSION} AS standard

COPY --from=ecr-builder /go/bin/docker-credential-ecr-login /usr/local/bin/docker-credential-ecr-login

RUN mkdir -p /root/.docker && \
    printf '{"credHelpers":{"public.ecr.aws":"ecr-login","*.dkr.ecr.*.amazonaws.com":"ecr-login"}}' \
    > /root/.docker/config.json

# ── Rootless variant ──────────────────────────────────────────────────────────
FROM moby/buildkit:${BUILDKIT_VERSION}-rootless AS rootless

# Switch to root temporarily to install the binary and configure the home dir
USER root

COPY --from=ecr-builder /go/bin/docker-credential-ecr-login /usr/local/bin/docker-credential-ecr-login

RUN mkdir -p /home/user/.docker && \
    printf '{"credHelpers":{"public.ecr.aws":"ecr-login","*.dkr.ecr.*.amazonaws.com":"ecr-login"}}' \
    > /home/user/.docker/config.json && \
    chown -R user:user /home/user/.docker

# Restore unprivileged user expected by the rootless entrypoint
USER user
