#!/bin/sh
# CustomKIMI auth launcher for this Mac. Installed over the `kimi` link that
# `npm link` creates (update.sh reinstalls it after every update and rollback).
# It exports the API keys from the login Keychain for EVERY launch context
# (interactive, non-interactive, scripts, 'kimi web', '/web') and turns off
# Kimi's own auto-updater. It runs whatever build the npm link points at, so
# --rollback keeps working. OPENROUTER_MANAGEMENT_KEY is deliberately NOT
# exported: Kimi reads it from the Keychain itself.
for key in CLOSEROUTER_API_KEY SEVENAPI_API_KEY OPENROUTER_API_KEY MUSE_FORWARDER_KEY GEMINI_FORWARDER_KEY; do
  eval "val=\${$key:-}"
  if [ -z "$val" ]; then
    val="$(security find-generic-password -a "$USER" -s "$key" -w 2>/dev/null || true)"
    [ -n "$val" ] && export "$key=$val"
  fi
done
# Trust the muse and gemini forwarders' self-signed certs when present (outbound TLS to the
# relays). NODE_EXTRA_CA_CERTS names a single file, so when both exist they are joined into
# forwarder-ca.pem, which is rewritten only when a cert changed.
forwarder_ca() {
  dir="$HOME/.kimi-code"
  set --
  for crt in "$dir/muse-forwarder.crt" "$dir/gemini-forwarder.crt"; do
    if [ -f "$crt" ]; then set -- "$@" "$crt"; fi
  done
  if [ $# -lt 2 ]; then
    [ $# -eq 0 ] || printf '%s\n' "$1"
    return 0
  fi
  bundle="$dir/forwarder-ca.pem"
  certs=$(for crt in "$@"; do cat "$crt" && echo; done)
  if [ "$certs" != "$(cat "$bundle" 2>/dev/null)" ]; then
    if ! { printf '%s\n' "$certs" >"$bundle.$$" && mv -f "$bundle.$$" "$bundle"; } 2>/dev/null; then
      rm -f "$bundle.$$"
      printf '%s\n' "$1"
      return 0
    fi
  fi
  printf '%s\n' "$bundle"
}
ca_file=$(forwarder_ca)
[ -n "$ca_file" ] && export NODE_EXTRA_CA_CERTS="$ca_file"

export KIMI_CODE_NO_AUTO_UPDATE=1
exec node "/opt/homebrew/lib/node_modules/@moonshot-ai/kimi-code/dist/main.mjs" "$@"
