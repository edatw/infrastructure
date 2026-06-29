# OpenClaw + OpenShell CLI image

Custom image = stock [OpenClaw](https://github.com/openclaw/openclaw) + the
NVIDIA [`openshell`](https://github.com/NVIDIA/OpenShell) CLI on `PATH`, required
by the `@openclaw/openshell-sandbox` plugin (which shells out to the binary).

The `OpenClawInstance` (`argocd/edatw-openclaw/base/openclawinstance.yaml`)
references this image via `spec.image`.

## Why a custom image (and why the `.deb`, not pip)

The OpenClaw base is **Debian 12 (glibc 2.36)**. The PyPI `openshell` wheels are
built for **glibc 2.39** (Debian 13 / Ubuntu 24.04) and publish **no sdist**, so
`pip`/`uv` can neither install nor run them on bookworm. The NVIDIA **native
`.deb`** only needs **glibc >= 2.28**, so it installs and runs on Debian 12 —
hence [Dockerfile](Dockerfile) fetches the pinned `.deb` and `dpkg -i`s it.

## Build & push

> Normally automated: [`.github/workflows/openclaw-image.yml`](../../../../.github/workflows/openclaw-image.yml)
> builds and pushes to `ghcr.io/edatw/openclaw-openshell` on a daily schedule
> (only when a new OpenClaw or OpenShell version appears), on changes to this
> directory, and on manual `workflow_dispatch` (with optional version inputs).
> First push creates the GHCR package as **private** — make it public, or add an
> image pull secret and set `spec.image.pullSecrets` on the OpenClawInstance.

To build manually instead (e.g. local testing): build for the architecture(s)
of the cluster nodes (Talos edatw-lab). `docker buildx` supplies `TARGETARCH`,
which selects the matching `.deb`.

```bash
# Set your registry (the cluster must be able to pull from it).
REGISTRY=ghcr.io/edatw          # <- adjust to your org/registry
IMAGE="$REGISTRY/openclaw-openshell"
TAG="2026.6.8-os0.0.71"          # openclaw version + openshell CLI version

# Multi-arch build + push (pick the platforms your nodes run):
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  --build-arg OPENCLAW_VERSION=2026.6.8 \
  --build-arg OPENSHELL_VERSION=0.0.71 \
  -t "$IMAGE:$TAG" \
  --push .
```

Then set `spec.image.repository`/`spec.image.tag` in the OpenClawInstance to
`$IMAGE` / `$TAG`. For a private registry, add `spec.image.pullSecrets`.

## Version bumps

- `OPENCLAW_VERSION` — tags at https://github.com/openclaw/openclaw/releases
- `OPENSHELL_VERSION` — tags at https://github.com/NVIDIA/OpenShell/releases
  (no leading `v`). The CLI line is independent of the OpenShell *gateway chart*
  version (`flux/base/openshell`); keep CLI >= 0.0.37 for gateway >= 0.0.37.
