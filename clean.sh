#!/usr/bin/env bash
set -euo pipefail
infile="$1"
outfile="$2"

# If file missing or only has header, write minimal M3U and exit
if [ ! -s "$infile" ] || ! grep -q '^#EXTINF' "$infile"; then
  echo "#EXTM3U" > "$outfile"
  echo "CLEAN: $(basename "$outfile"): kept=0, filtered_offline=0" >&2
  exit 0
fi

awk '
  BEGIN{ OFS="\t" }
  /^#EXTINF/ {
    ext = $0
    name = ext
    sub(/^.*,/, "", name)
    gsub(/^[ \t]+|[ \t]+$/, "", name)
    url = ""
    while ( (getline line) > 0 ) {
      if (line ~ /^#/) { continue }
      if (line ~ /^https?:\/\//) { url=line; break }
    }
    if (url != "" && !(name in seen)) {
      seen[name] = 1
      print tolower(name), ext, url
    }
  }
' "$infile" > _pairs.tsv

# If no pairs, produce empty playlist and exit
if [ ! -s _pairs.tsv ]; then
  echo "#EXTM3U" > "$outfile"
  echo "CLEAN: $(basename "$outfile"): kept=0, filtered_offline=0" >&2
  rm -f _pairs.tsv
  exit 0
fi

# Ensure files exist even if nothing is live
: > _live.tsv
: > _dead.tsv

# Probe reachability (HEAD → tiny GET fallback)
while IFS=$'\t' read -r key ext url; do
  if curl -fsSIL --max-time 6 -A "Mozilla/5.0 GitHubActions" -L "$url" >/dev/null 2>&1 \
  || curl -fsSL  --max-time 6 -A "Mozilla/5.0 GitHubActions" -L --range 0-0 "$url" >/dev/null 2>&1; then
    printf "%s\t%s\t%s\n" "$key" "$ext" "$url" >> _live.tsv
  else
    printf "%s\t%s\t%s\n" "$key" "$ext" "$url" >> _dead.tsv
  fi
done < _pairs.tsv

# Sort by name and rebuild M3U (handle empty _live.tsv)
{
  echo "#EXTM3U"
  if [ -s _live.tsv ]; then
    sort -f -t $'\t' -k1,1 _live.tsv | awk -F'\t' '{print $2 "\n" $3}'
  fi
} > "$outfile"

live=$(wc -l < _live.tsv 2>/dev/null || echo 0)
dead=$(wc -l < _dead.tsv 2>/dev/null || echo 0)
echo "CLEAN: $(basename "$outfile"): kept=${live}, filtered_offline=${dead}" >&2

rm -f _pairs.tsv _live.tsv _dead.tsv
