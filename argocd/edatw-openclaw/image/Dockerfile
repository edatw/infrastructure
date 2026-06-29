# Custom OpenClaw image: stock OpenClaw + the NVIDIA `openshell` CLI on PATH.
#
# WHY: the OpenClaw `@openclaw/openshell-sandbox` plugin shells out to the
# `openshell` CLI binary (config key plugins.entries.openshell.config.command,
# default "openshell"). The stock image has no such binary, so we bake it in.
#
# The base is Debian 12 (bookworm), user `node` (uid 1000), HOME=/home/node.
#
# INSTALL METHOD: the NVIDIA native .deb, NOT pip/uv. The PyPI `openshell` wheels
# are built for glibc 2.39 (Debian 13 / Ubuntu 24.04) and won't run on bookworm's
# glibc 2.36 (and ship no sdist). The native .deb only requires glibc >= 2.28, so
# it installs and runs on Debian 12. We fetch the pinned release asset and
# dpkg-install it (rather than piping the upstream install.sh through a shell).
# The package puts the binary on PATH for the runtime `node` user.
#
# COMPAT: OpenShell CLI >= 0.0.37 requires gateways >= 0.0.37; the deployed
# gateway (flux/base/openshell) is 0.0.42, so the latest CLI is compatible.
#
# We deliberately do NOT override the base ENTRYPOINT/CMD: the OpenClaw operator
# drives the pod, and the mTLS client bundle is staged via volume mounts on the
# OpenClawInstance (mounted at ~/.config/openshell/gateways/<name>/mtls/), not by
# an entrypoint wrapper.
ARG OPENCLAW_VERSION=2026.6.8
FROM ghcr.io/openclaw/openclaw:${OPENCLAW_VERSION}

# OpenShell CLI version (https://github.com/NVIDIA/OpenShell/releases), no leading v.
ARG OPENSHELL_VERSION=0.0.71
# Provided automatically by `docker buildx` (amd64 / arm64) -> matches .deb naming.
ARG TARGETARCH

USER root
RUN apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates curl \
 && curl -fsSL -o /tmp/openshell.deb \
      "https://github.com/NVIDIA/OpenShell/releases/download/v${OPENSHELL_VERSION}/openshell_${OPENSHELL_VERSION}-1_${TARGETARCH}.deb" \
 && (dpkg -i /tmp/openshell.deb || apt-get install -y -f --no-install-recommends) \
 && rm -f /tmp/openshell.deb \
 && rm -rf /var/lib/apt/lists/* \
 && openshell --version

USER node
