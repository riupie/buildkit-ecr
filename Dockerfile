# syntax=docker/dockerfile:1

ARG BUILDKIT_VERSION=v0.32.2
ARG ECR_HELPER_VERSION=v0.12.0

# Download the official pre-built binary for the target platform.
# Runs on the native build host (no QEMU) via --platform=$BUILDPLATFORM.
FROM --platform=$BUILDPLATFORM alpine:3 AS ecr-fetcher
ARG ECR_HELPER_VERSION
ARG TARGETARCH

RUN apk add --no-cache wget ca-certificates && \
    VERSION="${ECR_HELPER_VERSION#v}" && \
    wget -O /docker-credential-ecr-login \
      "https://amazon-ecr-credential-helper-releases.s3.us-east-2.amazonaws.com/${VERSION}/linux-${TARGETARCH}/docker-credential-ecr-login" && \
    chmod +x /docker-credential-ecr-login

# ── Standard (root) variant ───────────────────────────────────────────────────
FROM moby/buildkit:${BUILDKIT_VERSION} AS standard

COPY --from=ecr-fetcher /docker-credential-ecr-login /usr/local/bin/docker-credential-ecr-login

RUN mkdir -p /root/.docker && \
    printf '{"credHelpers":{"public.ecr.aws":"ecr-login","*.dkr.ecr.*.amazonaws.com":"ecr-login"}}' \
    > /root/.docker/config.json

# ── Rootless variant ──────────────────────────────────────────────────────────
FROM moby/buildkit:${BUILDKIT_VERSION}-rootless AS rootless

USER root

COPY --from=ecr-fetcher /docker-credential-ecr-login /usr/local/bin/docker-credential-ecr-login

RUN mkdir -p /home/user/.docker && \
    printf '{"credHelpers":{"public.ecr.aws":"ecr-login","*.dkr.ecr.*.amazonaws.com":"ecr-login"}}' \
    > /home/user/.docker/config.json && \
    chown -R user:user /home/user/.docker

USER user
