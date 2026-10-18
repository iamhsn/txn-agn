#!/usr/bin/env bash
# Create or refresh an agent workspace for one site. Run as root on the server:
#   /opt/txn-agn/scripts/site-workspace.sh <site> "<brand>" "<market>"
# Example: site-workspace.sh ladvalaw.com "Ladva Law" "people in San Francisco"
set -euo pipefail
site="$1"; brand="$2"; market="$3"
# Escape sed replacement specials (& and |) so a brand like "Dhobi & Co" survives.
esc() { printf '%s' "$1" | sed -e 's/[&|\\]/\\&/g'; }
brand_e="$(esc "$brand")"; market_e="$(esc "$market")"; site_e="$(esc "$site")"
dir="/home/agent/work/${site%%.*}"
src="$(cd "$(dirname "$0")/.." && pwd)/agents"
install -d -o agent -g agent "$dir" "$dir/data" "$dir/reports" "$dir/writer"
sed -e "s|{{SITE}}|$site_e|g" -e "s|{{BRAND}}|$brand_e|g" -e "s|{{MARKET}}|$market_e|g" "$src/seo-lead.md" > "$dir/AGENTS.md"
cp "$src/writer.md" "$dir/writer/AGENTS.md"
chown agent:agent "$dir/AGENTS.md" "$dir/writer/AGENTS.md"
echo "Workspace ready: $dir"
