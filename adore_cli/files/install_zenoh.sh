#!/usr/bin/env bash
set -euo pipefail

TMP_DIR="$(mktemp -d)"

cleanup() { rm -rf "${TMP_DIR}"; }
trap cleanup EXIT

detect_arch() {
    case "$(uname -m)" in
        x86_64)  echo "x86_64-unknown-linux-gnu" ;;
        aarch64) echo "aarch64-unknown-linux-gnu" ;;
        armv7l)  echo "armv7-unknown-linux-gnueabihf" ;;
        arm*)    echo "arm-unknown-linux-gnueabi" ;;
        *)
            echo "ERROR: unsupported architecture: $(uname -m)" >&2
            exit 1
            ;;
    esac
}

ARCH="$(detect_arch)"

echo "Installing dependencies..."
if command -v apt-get &>/dev/null; then
    apt-get install -y --no-install-recommends curl unzip ca-certificates
elif command -v yum &>/dev/null; then
    yum install -y curl unzip ca-certificates
else
    echo "WARNING: could not install dependencies, ensure curl and unzip are available" >&2
fi

echo "Fetching latest zenoh release version..."
VERSION=$(curl -fsSL "https://api.github.com/repos/eclipse-zenoh/zenoh/releases/latest" \
    | grep '"tag_name"' \
    | sed 's/.*"tag_name": *"\([^"]*\)".*/\1/')

if [ -z "${VERSION}" ]; then
    echo "ERROR: could not determine latest zenoh version from GitHub API" >&2
    exit 1
fi

ZIP="zenoh-${VERSION}-${ARCH}-debian.zip"
URL="https://download.eclipse.org/zenoh/zenoh/${VERSION}/${ZIP}"

echo "Installing zenoh ${VERSION} (${ARCH})"
echo "  Downloading ${URL}"

curl -fsSL "${URL}" -o "${TMP_DIR}/${ZIP}"
unzip -q "${TMP_DIR}/${ZIP}" -d "${TMP_DIR}/zenoh"

DEB=$(find "${TMP_DIR}/zenoh" -maxdepth 1 -name 'zenohd_*.deb' | head -1)
if [ -z "${DEB}" ]; then
    echo "ERROR: zenohd .deb not found in archive" >&2
    ls "${TMP_DIR}/zenoh/" >&2
    exit 1
fi

# Stub systemctl and sudo for the duration of dpkg install.
# zenohd's postinstall script calls both unconditionally and fails in
# any environment without systemd (containers, chroots, CI).
STUB_DIR="${TMP_DIR}/stub"
mkdir -p "${STUB_DIR}"
printf '#!/bin/sh\nexit 0\n' > "${STUB_DIR}/systemctl"
printf '#!/bin/sh\nshift; exec "$@"\n' > "${STUB_DIR}/sudo"
chmod +x "${STUB_DIR}/systemctl" "${STUB_DIR}/sudo"

echo "  Installing ${DEB##*/}"
PATH="${STUB_DIR}:${PATH}" dpkg -i "${DEB}"

echo "✓ $(zenohd --version 2>&1 | head -1)"
