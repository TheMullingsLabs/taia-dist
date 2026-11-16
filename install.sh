#!/bin/bash
set -euo pipefail

# TAIA setup installer for macOS (Apple silicon) and Linux / WSL (x64).
# Usage: curl -sL https://raw.githubusercontent.com/TheMullingsLabs/taia-dist/main/install.sh | bash
# Windows: download taia-setup-win-x64.exe from the Releases page instead.
#
# Source of truth: dist/install.sh in the private taia repo. taia-dist holds
# a copy, updated by hand whenever this file changes.
# Modeled on goat-saas-agent-dist/install.sh.

DIST_REPO="TheMullingsLabs/taia-dist"
INSTALL_DIR="${HOME}/.local/bin"
API_BASE="https://api.github.com/repos/${DIST_REPO}"
DOWNLOAD_BASE="https://github.com/${DIST_REPO}/releases/download"
LATEST_URL="${API_BASE}/releases/latest"
# Test hook: tests point this at a local file:// folder laid out like the release site
# (<base>/releases/latest, <base>/releases/download/<tag>/<file>). Unset in normal use.
if [ -n "${TAIA_INSTALL_BASE_URL:-}" ]; then
  LATEST_URL="${TAIA_INSTALL_BASE_URL}/releases/latest"
  DOWNLOAD_BASE="${TAIA_INSTALL_BASE_URL}/releases/download"
fi

EXIT_NO_RELEASE=10
EXIT_DOWNLOAD=11
EXIT_CHECKSUM=12
EXIT_INSTALL=13

# Network limits apply to a stalled or dead connection only, never to a download that is
# still moving: no connection in 20 s, or under 1 KB/s for 60 s, aborts; transient errors
# retry. There is deliberately no overall time limit.
CURL_NET=(--connect-timeout 20 --speed-limit 1024 --speed-time 60 --retry 3 --retry-delay 2)
if [ -t 1 ]; then
  CURL_PROGRESS=(--progress-bar)
else
  CURL_PROGRESS=(-sS)
fi

# Every run works in its own temporary folder, removed on exit, so two runs never share
# files and an interrupted run leaves nothing behind.
WORK="$(mktemp -d)"
trap 'rm -rf "${WORK}"' EXIT
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM

OS="$(uname -s | tr '[:upper:]' '[:lower:]')"
ARCH="$(uname -m)"
case "${OS}" in
  linux*)  PLATFORM="linux" ;;
  darwin*) PLATFORM="darwin" ;;
  *)       echo "Unsupported system: ${OS}. On Windows, download the .exe from the Releases page."; exit 1 ;;
esac
case "${ARCH}" in
  x86_64|amd64)  ARCH="x64" ;;
  aarch64|arm64) ARCH="arm64" ;;
  *)             echo "Unsupported processor: ${ARCH}. Contact The Mullings Group."; exit 1 ;;
esac
TARGET="${PLATFORM}-${ARCH}"
case "${TARGET}" in
  linux-x64|darwin-arm64) ;;
  *) echo "TAIA setup is not built for ${TARGET} yet. Contact The Mullings Group."; exit 1 ;;
esac
BINARY_NAME="taia-setup-${TARGET}"

# A pinned version (TAIA_VERSION=v1.3.0) skips the "latest release" lookup.
TAG="${TAIA_VERSION:-}"
if [ -z "${TAG}" ]; then
  echo "Finding the latest version..."
  if curl -fsSL "${CURL_NET[@]}" "${LATEST_URL}" -o "${WORK}/latest.json"; then
    TAG=$(grep '"tag_name"' "${WORK}/latest.json" | sed 's/.*"tag_name": *"\([^"]*\)".*/\1/' || true)
  fi
  if [ -z "${TAG}" ]; then
    echo "ERROR: Could not find a published version of TAIA setup."
    echo "Check your internet connection and try again. If it keeps happening, contact The Mullings Group."
    exit "${EXIT_NO_RELEASE}"
  fi
fi
echo "Version: ${TAG}"

echo "Downloading ${BINARY_NAME}..."
if ! curl -fL "${CURL_NET[@]}" "${CURL_PROGRESS[@]}" "${DOWNLOAD_BASE}/${TAG}/${BINARY_NAME}" -o "${WORK}/${BINARY_NAME}"; then
  echo "ERROR: Download failed. Nothing was installed."
  exit "${EXIT_DOWNLOAD}"
fi

CHECKSUM_NAME="checksums-${TARGET}.txt"
if ! curl -fsSL "${CURL_NET[@]}" "${DOWNLOAD_BASE}/${TAG}/${CHECKSUM_NAME}" -o "${WORK}/${CHECKSUM_NAME}"; then
  echo "ERROR: Checksum download failed. Nothing was installed."
  exit "${EXIT_DOWNLOAD}"
fi

echo "Checking the download..."
CHECK_OK=1
if command -v sha256sum >/dev/null 2>&1; then
  (cd "${WORK}" && sha256sum -c "${CHECKSUM_NAME}" --quiet) || CHECK_OK=0
elif command -v shasum >/dev/null 2>&1; then
  (cd "${WORK}" && shasum -a 256 -c "${CHECKSUM_NAME}" >/dev/null) || CHECK_OK=0
else
  echo "ERROR: No checksum tool (sha256sum or shasum) found. Nothing was installed."
  exit "${EXIT_CHECKSUM}"
fi
if [ "${CHECK_OK}" -ne 1 ]; then
  echo "ERROR: The download did not match its checksum. Nothing was installed."
  exit "${EXIT_CHECKSUM}"
fi

# Copy next to the target, then rename over it, so the installed file is either the old
# one or the complete new one, never a partial file.
if ! {
  mkdir -p "${INSTALL_DIR}" &&
    cp "${WORK}/${BINARY_NAME}" "${INSTALL_DIR}/.taia-setup.new.$$" &&
    chmod +x "${INSTALL_DIR}/.taia-setup.new.$$" &&
    mv -f "${INSTALL_DIR}/.taia-setup.new.$$" "${INSTALL_DIR}/taia-setup"
}; then
  rm -f "${INSTALL_DIR}/.taia-setup.new.$$"
  echo "ERROR: Install failed. Nothing was changed."
  exit "${EXIT_INSTALL}"
fi

# Make sure the install folder is on PATH for new terminals.
PATH_UPDATED=""
case ":${PATH}:" in
  *":${INSTALL_DIR}:"*) ;;
  *)
    case "$(basename "${SHELL:-/bin/bash}")" in
      zsh)  SHELL_RC="${HOME}/.zshrc" ;;
      fish) SHELL_RC="${HOME}/.config/fish/config.fish" ;;
      *)
        # Terminal on a Mac starts login shells, which read .bash_profile.
        if [ "${PLATFORM}" = "darwin" ]; then
          SHELL_RC="${HOME}/.bash_profile"
        else
          SHELL_RC="${HOME}/.bashrc"
        fi
        ;;
    esac
    # A second run in the same terminal must not add the line again.
    if ! grep -qsF "${INSTALL_DIR}" "${SHELL_RC}"; then
      if [ "$(basename "${SHELL_RC}")" = "config.fish" ]; then
        mkdir -p "$(dirname "${SHELL_RC}")"
        echo "set -gx PATH ${INSTALL_DIR} \$PATH" >> "${SHELL_RC}"
      else
        echo "export PATH=\"${INSTALL_DIR}:\${PATH}\"" >> "${SHELL_RC}"
      fi
    fi
    PATH_UPDATED="${SHELL_RC}"
    ;;
esac

echo ""
echo "  TAIA setup ${TAG} is installed at ${INSTALL_DIR}/taia-setup"
echo ""
if [ -n "${PATH_UPDATED}" ]; then
  echo "  Open a new terminal window, then run:"
else
  echo "  Now run:"
fi
echo ""
echo "    taia-setup"
echo ""
