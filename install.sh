#!/bin/bash
set -euo pipefail

# TAIA installer for macOS (Apple silicon and Intel) and Linux / WSL (x64).
# Usage: curl -fsSL https://gettaia.app/install.sh | bash
# (gettaia.app/install.sh sends the browser or curl here:
#  https://raw.githubusercontent.com/TheMullingsLabs/taia-dist/main/install.sh)
# Windows: download taia-win-x64.exe from https://gettaia.app/download instead.
#
# It installs ~/.local/bin/taia, puts the TAIA icon on the desktop
# (`taia install`), then starts the guided setup in this same terminal.
#
# Source of truth: dist/install.sh in the private taia repo. taia-dist holds
# a copy, updated only through a pull request, and only once a release
# signed for this script is published (docs/ADMIN_GUIDE.md section 9b).
# Modeled on goat-saas-agent-dist/install.sh.
#
# Everything runs inside main(), called on the last line, so a download cut
# off part way through runs nothing.

# The public half of TMG's release signing key (release_key.py holds the same).
RELEASE_KEY_PEM='-----BEGIN PUBLIC KEY-----
MIIBojANBgkqhkiG9w0BAQEFAAOCAY8AMIIBigKCAYEAwLVhdTiuO8ld4rbaiHh0
89HfGwHijNrAL+v3C4ZKsgmpEkkQUT6A6gGFpyfJNq/pFq/la5bRWZTrT1C0TBH+
A0bxbhKtG39Jk3mNUXodSOqoRZpJlYfPSiYkEZzZbZpGZjZbtkAQY65nSEvgq2PF
3cL5M08D8PJksHLgsNSFKMfjiHqV2U25aKDhuQvPOS2qh2Z4xQbzJrYbN9PrNZad
m/3qvWiT8XKL/x48KqUsKEYW1vZwjuikvW02NDfTl3JI3sUtpmPvzFTQVBfAMNwg
AvV27OjVWmFkETCoJmaA8j2ioFr4YwbW+cdZHUiyztEi+RSFkXpF5Do1xGiXyrQI
/aOZNl7ah/8niE7XbBbH6tB6dEclDFk4nTO8Vrk2dzh9b+ot/RGCIhegSatSn/Ai
AMlii5z/45l94scVxacAphp6dKfazXKhk6QHkzWweVtvYHJe4T2AJa8IjUaigiP6
AeIkP4EOsNeFdi8XGaB13UO+FXwY6sj+FQgt6zH8mwItAgMBAAE=
-----END PUBLIC KEY-----'

main() {
  DIST_REPO="TheMullingsLabs/taia-dist"
  INSTALL_DIR="${HOME}/.local/bin"
  API_BASE="https://api.github.com/repos/${DIST_REPO}"
  DOWNLOAD_BASE="https://github.com/${DIST_REPO}/releases/download"
  LATEST_URL="${API_BASE}/releases/latest"

  EXIT_NO_RELEASE=10
  EXIT_DOWNLOAD=11
  EXIT_CHECKSUM=12
  EXIT_INSTALL=13
  EXIT_SIGNATURE=14

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
    *)       echo "Unsupported system: ${OS}. On Windows, download TAIA from https://gettaia.app/download instead."; exit 1 ;;
  esac
  case "${ARCH}" in
    x86_64|amd64)  ARCH="x64" ;;
    aarch64|arm64) ARCH="arm64" ;;
    *)             echo "Unsupported processor: ${ARCH}. Contact The Mullings Group."; exit 1 ;;
  esac
  TARGET="${PLATFORM}-${ARCH}"
  case "${TARGET}" in
    linux-x64|darwin-arm64|darwin-x64) ;;
    *) echo "TAIA is not built for ${TARGET} yet. Contact The Mullings Group."; exit 1 ;;
  esac
  BINARY_NAME="taia-${TARGET}"

  # The download's signature is checked with openssl, so check it is here
  # before downloading anything.
  if ! command -v openssl >/dev/null 2>&1; then
    echo "ERROR: TAIA's installer needs openssl to check the download, and it isn't installed. Nothing was installed."
    echo "On Ubuntu or WSL, install it with: sudo apt install openssl"
    exit "${EXIT_SIGNATURE}"
  fi

  # A pinned version (TAIA_VERSION=v1.3.0) skips the "latest release" lookup.
  TAG="${TAIA_VERSION:-}"
  if [ -z "${TAG}" ]; then
    echo "Finding the latest version..."
    if curl -fsSL "${CURL_NET[@]}" "${LATEST_URL}" -o "${WORK}/latest.json"; then
      TAG=$(grep '"tag_name"' "${WORK}/latest.json" | sed 's/.*"tag_name": *"\([^"]*\)".*/\1/' || true)
    fi
    if [ -z "${TAG}" ]; then
      echo "ERROR: Could not find a published version of TAIA."
      echo "Check your internet connection and try again. If it keeps happening, contact The Mullings Group."
      exit "${EXIT_NO_RELEASE}"
    fi
  fi
  # Only a version like v1.3.0 or v1.3.0-test.1 (the license server's pattern).
  TAG_PATTERN='^v[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.]+)?$'
  if ! [[ "${TAG}" =~ ${TAG_PATTERN} ]]; then
    echo "ERROR: \"${TAG}\" is not a TAIA version (like v1.3.0). Nothing was installed."
    exit "${EXIT_NO_RELEASE}"
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

  # The checksum file comes from the same place as the binary, so on its own it
  # only catches a damaged download. Its signature, made by TMG's release build
  # with a key that never leaves it, proves TMG published it.
  if ! curl -fsSL "${CURL_NET[@]}" "${DOWNLOAD_BASE}/${TAG}/${CHECKSUM_NAME}.sig" -o "${WORK}/${CHECKSUM_NAME}.sig"; then
    echo "ERROR: Could not get the signature for ${TAG}. Nothing was installed."
    echo "Check your internet connection and try again. If it keeps happening, contact The Mullings Group."
    exit "${EXIT_DOWNLOAD}"
  fi
  printf '%s\n' "${RELEASE_KEY_PEM}" > "${WORK}/release-key.pem"
  if ! openssl dgst -sha256 -verify "${WORK}/release-key.pem" -signature "${WORK}/${CHECKSUM_NAME}.sig" \
      "${WORK}/${CHECKSUM_NAME}" >/dev/null 2>&1; then
    echo "ERROR: The download is not signed by The Mullings Group. Nothing was installed."
    echo "Contact The Mullings Group."
    exit "${EXIT_SIGNATURE}"
  fi
  # The signed first line names the release, so an older release's signed
  # files can't be passed off as this one.
  if [ "$(head -n 1 "${WORK}/${CHECKSUM_NAME}" | tr -d '\r')" != "version: ${TAG}" ]; then
    echo "ERROR: The signed checksum file is not for ${TAG}. Nothing was installed."
    echo "Contact The Mullings Group."
    exit "${EXIT_SIGNATURE}"
  fi

  echo "Checking the download..."
  # Only the binary's own line (the file also has the version line).
  grep -E "^[0-9a-fA-F]{64} [ *]${BINARY_NAME}\$" "${WORK}/${CHECKSUM_NAME}" > "${WORK}/binary.sha256" || true
  CHECK_OK=1
  if [ ! -s "${WORK}/binary.sha256" ]; then
    CHECK_OK=0
  elif command -v sha256sum >/dev/null 2>&1; then
    (cd "${WORK}" && sha256sum -c binary.sha256 --quiet) || CHECK_OK=0
  elif command -v shasum >/dev/null 2>&1; then
    (cd "${WORK}" && shasum -a 256 -c binary.sha256 >/dev/null) || CHECK_OK=0
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
      cp "${WORK}/${BINARY_NAME}" "${INSTALL_DIR}/.taia.new.$$" &&
      chmod +x "${INSTALL_DIR}/.taia.new.$$" &&
      mv -f "${INSTALL_DIR}/.taia.new.$$" "${INSTALL_DIR}/taia" &&
      # The old name, for anyone following older steps.
      ln -sfn taia "${INSTALL_DIR}/taia-setup"
  }; then
    rm -f "${INSTALL_DIR}/.taia.new.$$"
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
  echo "  TAIA ${TAG} is installed at ${INSTALL_DIR}/taia"
  echo ""

  # The desktop icon. TAIA still works from the terminal if this fails.
  "${INSTALL_DIR}/taia" install || echo "  The desktop icon could not be made. You can still type: taia go"

  # Start the guided setup (or, if TAIA is already set up, open the Dashboard)
  # right here. The script itself comes through a pipe, so the questions read
  # the keyboard from /dev/tty. Not in a terminal: say what to run instead.
  if [ -t 1 ] && (exec </dev/tty) 2>/dev/null; then
    echo ""
    "${INSTALL_DIR}/taia" </dev/tty
  else
    echo ""
    if [ -n "${PATH_UPDATED}" ]; then
      echo "  Open a new terminal window, then run:"
    else
      echo "  Now run:"
    fi
    echo ""
    echo "    taia"
    echo ""
  fi
}

main "$@"
