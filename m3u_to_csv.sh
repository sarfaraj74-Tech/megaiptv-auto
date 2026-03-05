#!/usr/bin/env bash
set -euo pipefail
infile="$1"
outfile="$2"
echo "name,url" > "$outfile"
if grep -q '^#EXTINF' "$infile"; then
  awk '
    /^#EXTINF/ {
      ext=$0
      name=ext
      sub(/^.*,/, "", name)
      gsub(/^[ \t]+|[ \t]+$/, "", name)
      getline url
      if (url ~ /^https?:\/\//) {
        gsub(/"/, "\"\"", name)
        printf "\"%s\",%s\n", name, url
      }
    }
  ' "$infile" >> "$outfile"
fi
