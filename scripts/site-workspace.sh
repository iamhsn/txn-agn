#!/usr/bin/env bash
# Create or refresh an agent workspace for one site. Run as root on the server:
#   /opt/txn-agn/scripts/site-workspace.sh <site> "<brand>" "<market>"
# Example: site-workspace.sh ladvalaw.com "Ladva Law" "people in San Francisco"
set -euo pipefail
site="$1"; brand="$2"; market="$3"
dir="/home/agent/work/${site%%.*}"
src="$(cd "$(dirname "$0")/.." && pwd)/agents"
install -d -o agent -g agent "$dir" "$dir/data" "$dir/reports" "$dir/writer"
sed -e "s|{{SITE}}|$site|g" -e "s|{{BRAND}}|$brand|g" -e "s|{{MARKET}}|$market|g" "$src/seo-lead.md" > "$dir/AGENTS.md"
cp "$src/writer.md" "$dir/writer/AGENTS.md"
chown agent:agent "$dir/AGENTS.md" "$dir/writer/AGENTS.md"
echo "Workspace ready: $dir"
