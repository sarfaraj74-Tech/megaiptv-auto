#!/usr/bin/env bash
set -euo pipefail
url="$1"; outfile="$2"
if ! curl -fsSL --retry 3 --retry-delay 2 --max-time 20 -A "Mozilla/5.0 GitHubActions" -L "$url" >> "$outfile"; then
  echo "WARN: skipping (HTTP 404/timeout): $url" >&2
fi
