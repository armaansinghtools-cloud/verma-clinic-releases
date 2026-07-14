#!/bin/sh
# One-line installer for the Verma Homeopathic Clinic desktop app.
#
#   curl -fsSL https://raw.githubusercontent.com/armaansinghtools-cloud/verma-clinic-releases/main/install.sh | sh
#
# Always installs the newest published version. Replaces an existing install;
# clinic data, settings, and backups live outside the app and are kept.
# The canonical copy of this file lives in the PRIVATE repo at scripts/install.sh —
# `npm run release -- --publish` pushes it to the public releases repo. Edit it
# there, never directly on the public repo.
#
# Terminal downloads carry no macOS quarantine attribute, so this path never
# triggers the Gatekeeper "damaged app" dialog that browser downloads hit
# (see docs/app-distribution-and-updates.md in the private repo).
set -eu

REPO="armaansinghtools-cloud/verma-clinic-releases"
APP_NAME="Verma Homeopathic Clinic"

say() { printf '%s\n' "$*"; }
fail() { printf 'PROBLEM: %s\n' "$*" >&2; exit 1; }

[ "$(uname)" = "Darwin" ] || fail "This installer is for macOS only."
[ "$(uname -m)" = "arm64" ] || fail "This app needs a Mac with Apple Silicon (M1 or newer). This Mac has an Intel processor."

say "Finding the newest version..."
LATEST_JSON="$(curl -fsSL "https://github.com/$REPO/releases/latest/download/latest.json")" \
  || fail "Could not reach the download server. Check the internet connection and try again."
VERSION="$(printf '%s' "$LATEST_JSON" | sed -n 's/.*"version"[^"]*"\([^"]*\)".*/\1/p' | head -1)"
URL="$(printf '%s' "$LATEST_JSON" | sed -n 's/.*"url"[^"]*"\([^"]*\)".*/\1/p' | head -1)"
[ -n "$VERSION" ] && [ -n "$URL" ] || fail "Could not read the newest version information. Try again in a few minutes."

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

say "Downloading $APP_NAME $VERSION..."
curl -fL --progress-bar -o "$TMP_DIR/app.tar.gz" "$URL" \
  || fail "The download failed. Check the internet connection and try again."

mkdir "$TMP_DIR/extract"
tar -xzf "$TMP_DIR/app.tar.gz" -C "$TMP_DIR/extract" \
  || fail "The downloaded file could not be unpacked. Try again."
[ -d "$TMP_DIR/extract/$APP_NAME.app" ] || fail "The download did not contain the app. Try again later."

DEST="/Applications"
if [ ! -w "$DEST" ]; then
  DEST="$HOME/Applications"
  mkdir -p "$DEST"
fi

# Politely quit the app if it is running (no-op otherwise), then swap the bundle.
osascript -e "tell application \"$APP_NAME\" to quit" >/dev/null 2>&1 || true
sleep 1
if [ -d "$DEST/$APP_NAME.app" ]; then
  say "Replacing the existing app (clinic data and settings are kept)..."
  rm -rf "$DEST/$APP_NAME.app"
fi
mv "$TMP_DIR/extract/$APP_NAME.app" "$DEST/$APP_NAME.app"

say "Installed $APP_NAME $VERSION in $DEST."
open "$DEST/$APP_NAME.app"
say "Done — the app is opening now. From here it keeps itself up to date automatically."
