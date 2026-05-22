# buildkit-ecr

[BuildKit](https://github.com/moby/buildkit) with [`amazon-ecr-credential-helper`](https://github.com/awslabs/amazon-ecr-credential-helper) pre-installed and configured.

Designed for running BuildKit inside **AWS EKS with IRSA** (IAM Roles for Service Accounts) so it can pull and push to ECR without managing static credentials.

## Images

| Variant | Image | Notes |
|---|---|---|
| Standard (root) | `riupie/buildkit-ecr:latest` | Runs as root |
| Rootless | `riupie/buildkit-ecr:latest-rootless` | Runs as unprivileged user, no `--privileged` needed |

Available platforms: `linux/amd64`, `linux/arm64`

## Why this image?

The official `moby/buildkit` image has no AWS credential support. When you run BuildKit as a pod in EKS and try to push to ECR, authentication fails unless you:

1. Mount static AWS credentials — **not recommended**
2. Use a node IAM role — too permissive for multi-tenant clusters
3. Use IRSA — the right answer, but requires the `ecr-login` credential helper inside the BuildKit container

This image ships the credential helper and a pre-configured `~/.docker/config.json` so BuildKit picks it up automatically:

```json
{
  "credHelpers": {
    "public.ecr.aws": "ecr-login",
    "*.dkr.ecr.*.amazonaws.com": "ecr-login"
  }
}
```

## License

MIT
