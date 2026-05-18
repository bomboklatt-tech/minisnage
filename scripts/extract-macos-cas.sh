#!/usr/bin/env bash
# Dump macOS keychain certs (system + system roots + login) as one PEM bundle.
# Used to feed corp CA certs into the nix-darwin linux-builder so it can
# verify cache.nixos.org through MITM TLS inspection.
set -euo pipefail

OUT="${1:?usage: $0 <output.pem>}"

{
  security find-certificate -a -p /Library/Keychains/System.keychain
  security find-certificate -a -p /System/Library/Keychains/SystemRootCertificates.keychain
  if [ -f "$HOME/Library/Keychains/login.keychain-db" ]; then
    security find-certificate -a -p "$HOME/Library/Keychains/login.keychain-db"
  fi
} > "$OUT"

echo "Wrote $(grep -c '^-----BEGIN CERTIFICATE-----' "$OUT") certs to $OUT"
