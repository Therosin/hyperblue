#!/usr/bin/env bash
# Install the Lite XL plugin manager (lpm) as a system binary.
#
# lpm is a single static binary published on GitHub Releases. It is pinned by
# version and checked against the SHA-256 the release advertises, so a moved or
# compromised release fails the build instead of shipping silently.
set -euo pipefail

# Digests are published per release, so the version is not overridable: bumping
# it without also bumping the digests below would only trade a clean download
# for a checksum failure.
VERSION=1.5.1
BASE="https://github.com/lite-xl/lite-xl-plugin-manager/releases/download"

case "$(uname -m)" in
    x86_64) LPM_ARCH=x86_64-linux; LPM_SHA256=5c968134cd71f9e94fc4995dcec37a396249c084b03c4f508ad28f35696f14c9 ;;
    aarch64) LPM_ARCH=aarch64-linux; LPM_SHA256=cb79365e2825d1e4eab16060f8037eabf13524715fa5a21ad77c99422b23ec72 ;;
    *)
        echo "lpm: unsupported architecture $(uname -m)" >&2
        exit 1
        ;;
esac

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

curl -fsSL --retry 3 --retry-delay 5 \
    -o "$tmp/lpm" "$BASE/v$VERSION/lpm.$LPM_ARCH"

printf '%s  %s\n' "$LPM_SHA256" "$tmp/lpm" | sha256sum -c --quiet -

install -D -m 0755 "$tmp/lpm" /usr/bin/lpm
/usr/bin/lpm --version
