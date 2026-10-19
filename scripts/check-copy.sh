#!/usr/bin/env bash
# Reviewer: check a Writer draft before it goes to the Developer.
#   check-copy.sh <draft-file> [--site ladvalaw.com]
# The draft may contain any of:
#   TITLE: <text>            50-60 characters
#   META: <text>             140-155 characters
#   JSON-LD in a ```json fence or a <script type="application/ld+json"> block   must parse as JSON
# Exit 0 = pass, 1 = fail (reasons printed), 2 = usage error. WARN lines never fail the check but
# SEO Lead must verify them against the facts in the task.
set -euo pipefail
file="${1:-}"; shift || true
site=""
while [ $# -gt 0 ]; do case "$1" in --site) site="${2:-}"; shift 2;; *) echo "unknown option $1" >&2; exit 2;; esac; done
[ -n "$file" ] && [ -r "$file" ] || { echo "usage: check-copy.sh <draft-file> [--site <domain>]" >&2; exit 2; }
command -v python3 >/dev/null || { echo "python3 not found" >&2; exit 2; }

python3 - "$file" "$site" <<'PY'
import json, re, sys
path, site = sys.argv[1], sys.argv[2].lower()
text = open(path, encoding="utf-8").read()
fails, warns, checked = [], [], []

def field(name):
    m = re.search(r'^\s*%s:\s*(.+?)\s*$' % name, text, re.I | re.M)
    return m.group(1).strip().strip('"') if m else None

title, meta = field("TITLE"), field("META")
if title is not None:
    checked.append("title")
    if not 50 <= len(title) <= 60: fails.append("title is %d characters, need 50-60: %s" % (len(title), title))
if meta is not None:
    checked.append("meta")
    if not 140 <= len(meta) <= 155: fails.append("meta description is %d characters, need 140-155: %s" % (len(meta), meta))

blocks = re.findall(r'```json\s*(.*?)```', text, re.S | re.I)
blocks += re.findall(r'<script[^>]*application/ld\+json[^>]*>(.*?)</script>', text, re.S | re.I)
for i, b in enumerate(blocks, 1):
    checked.append("json-ld #%d" % i)
    try:
        d = json.loads(b)
        items = d if isinstance(d, list) else d.get("@graph", [d]) if isinstance(d, dict) else []
        if not any(isinstance(x, dict) and x.get("@type") for x in items): fails.append("JSON-LD #%d has no @type" % i)
        if isinstance(d, dict) and "@context" not in d and "@graph" not in d: fails.append("JSON-LD #%d has no @context" % i)
    except Exception as e:
        fails.append("JSON-LD #%d is not valid JSON: %s" % (i, str(e)[:80]))

if not checked: fails.append("nothing to check: add TITLE:, META: or a JSON-LD block")

# placeholders left in the copy
for pat, label in ((r'\[[A-Z][A-Z0-9 _/&-]*(?:[—–-]+ ?[A-Za-z ]+)?\]', "bracket placeholder"), (r'\bTODO\b|\bTBD\b|\bXXX\b', "TODO/TBD/XXX"),
                   (r'\{\{[^}]*\}\}', "unfilled {{template}}"), (r'lorem ipsum', "lorem ipsum"), (r'\bconfirm\b[^.\n]*\]', "'confirm' note")):
    for m in re.findall(pat, text, re.I if label in ("lorem ipsum",) else 0):
        fails.append("placeholder left in copy (%s): %s" % (label, m[:60]))

# claims that need a source in the task facts
for w in re.findall(r'\b(free|cheapest|lowest price|#1|number one|100%|guarantee[sd]?|best)\b', text, re.I):
    warns.append("claim '%s' must be backed by a fact in the task" % w)

# law firm rules
if "ladvalaw" in site or "law" in site:
    bad = (r'\bbest\b', r'\bguarantee[sd]?\b', r'\bspecialist[s]?\b', r'\bwe will (win|get|recover|obtain)\b', r'\bwin your case\b',
           r'\bget you (the |your )?(money|compensation|settlement|maximum)\b', r'\byou will (receive|recover|get|win)\b', r'\bmaximum compensation\b', r'\bproven results\b')
    for p in bad:
        for m in re.finditer(p, text, re.I): fails.append("not allowed for a law firm: '%s'" % m.group(0))
    warns = [w for w in warns if "'best'" not in w.lower() and "'guarantee" not in w.lower()]

seen = set(); fails = [f for f in fails if not (f in seen or seen.add(f))]
for w in dict.fromkeys(warns): print("WARN:", w)
if fails:
    for f in fails: print("FAIL:", f)
    print("RESULT: FAIL (%d problems)" % len(fails)); sys.exit(1)
print("RESULT: PASS (checked: %s)" % ", ".join(checked))
PY
