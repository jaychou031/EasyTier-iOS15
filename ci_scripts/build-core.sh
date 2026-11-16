#!/bin/bash
set -euo pipefail

if [[ -f "${HOME}/.cargo/env" ]]; then
    source "${HOME}/.cargo/env"
fi
export PATH="${HOME}/.local/bin:${PATH}"
if [[ -f /opt/homebrew/bin/brew ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
fi

cd "${PROJECT_DIR}/Core"
for arch in ${ARCHS}; do
    case "$arch" in
        arm64) prefix=aarch64 ;;
        x86_64) prefix=x86_64 ;;
        *) echo "Unsupported architecture: $arch" >&2; exit 1 ;;
    esac
    case "${PLATFORM_NAME}" in
        iphoneos)
            target="${prefix}-apple-ios"
            export IPHONEOS_DEPLOYMENT_TARGET="${IPHONEOS_DEPLOYMENT_TARGET:-15.0}"
            ;;
        iphonesimulator)
            if [[ "$arch" == arm64 ]]; then
                target=aarch64-apple-ios-sim
            else
                target=x86_64-apple-ios
            fi
            export IPHONEOS_DEPLOYMENT_TARGET="${IPHONEOS_DEPLOYMENT_TARGET:-15.0}"
            ;;
        macosx) target="${prefix}-apple-darwin" ;;
        *) echo "Unsupported platform: ${PLATFORM_NAME}" >&2; exit 1 ;;
    esac
    args=(--locked --target "$target")
    if [[ "${CONFIGURATION}" != Debug ]]; then
        args+=(--release)
    fi
    cargo build "${args[@]}"
done
