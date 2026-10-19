#!/usr/bin/env bash
# Create or refresh an agent workspace for one site. Run as root on the server:
#   /opt/txn-agn/scripts/site-workspace.sh <site> "<brand>" "<market>" [<wordpress base url>]
# Example: site-workspace.sh ladvalaw.com "Ladva Law" "people in San Francisco" https://www.ladvalaw.com
# Creates <dir>/AGENTS.md (SEO Lead), writer/AGENTS.md, developer/AGENTS.md, bin/check-copy.sh and drafts/.
set -euo pipefail
site="$1"; brand="$2"; market="$3"; base="${4:-https://$site}"
# Escape sed replacement specials (& and |) so a brand like "Dhobi & Co" survives.
esc() { printf '%s' "$1" | sed -e 's/[&|\\]/\\&/g'; }
brand_e="$(esc "$brand")"; market_e="$(esc "$market")"; site_e="$(esc "$site")"; base_e="$(esc "${base%/}")"
# WP_<SITEKEY>_USER / WP_<SITEKEY>_APP_PASSWORD: first label of the domain, upper case, letters and digits only.
sitekey="$(printf '%s' "${site%%.*}" | tr '[:lower:]' '[:upper:]' | tr -cd 'A-Z0-9')"
dir="/home/agent/work/${site%%.*}"
root="$(cd "$(dirname "$0")/.." && pwd)"; src="$root/agents"
render() { sed -e "s|{{SITE}}|$site_e|g" -e "s|{{BRAND}}|$brand_e|g" -e "s|{{MARKET}}|$market_e|g" -e "s|{{WPBASE}}|$base_e|g" -e "s|{{SITEKEY}}|$sitekey|g" "$1"; }
install -d -o agent -g agent "$dir" "$dir/data" "$dir/reports" "$dir/drafts" "$dir/bin" "$dir/writer" "$dir/developer"
render "$src/seo-lead.md"  > "$dir/AGENTS.md"
render "$src/writer.md"    > "$dir/writer/AGENTS.md"
render "$src/developer.md" > "$dir/developer/AGENTS.md"
install -o agent -g agent -m 755 "$root/scripts/check-copy.sh" "$dir/bin/check-copy.sh"
chown agent:agent "$dir/AGENTS.md" "$dir/writer/AGENTS.md" "$dir/developer/AGENTS.md"
if grep -l '{{' "$dir/AGENTS.md" "$dir/writer/AGENTS.md" "$dir/developer/AGENTS.md" >/dev/null 2>&1; then echo "WARNING: unfilled {{placeholders}} left in $dir" >&2; fi
echo "Workspace ready: $dir (WordPress credentials expected in WP_${sitekey}_USER and WP_${sitekey}_APP_PASSWORD)"
