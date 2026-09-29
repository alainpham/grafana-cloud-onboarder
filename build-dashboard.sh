#!/usr/bin/env bash
# Generate the Grafana Cloud dashboard (Business Text panel) from the standalone HTML page.
#
#   ./build-dashboard.sh [page.html] [template.json] [output.json]
#
# The page must contain exactly one <script>…</script> block. Grafana's Content-Security-Policy
# blocks inline <script> inside the panel's frame, so the panel loads the markup and the code
# separately: the template's afterRender placeholder /*@@PAGE@@*/ becomes
#   const HTML = "<page without its script>";
#   const CODE = "<the script body>";
# Requires: bash, jq 1.6+.
set -euo pipefail

cd "$(dirname "$0")"
PAGE=${1:-grafana-cloud-onboarder.html}
TEMPLATE=${2:-dashboard.template.json}
OUT=${3:-grafana-cloud-onboarder.dashboard.json}
PLACEHOLDER='/*@@PAGE@@*/'
PANEL_OPTS='.spec.elements["panel-1"].spec.vizConfig.spec.options'

command -v jq >/dev/null || { echo "error: jq is required" >&2; exit 1; }
[[ -f $PAGE ]] || { echo "error: page not found: $PAGE" >&2; exit 1; }
[[ -f $TEMPLATE ]] || { echo "error: template not found: $TEMPLATE" >&2; exit 1; }

jq --rawfile page "$PAGE" --arg ph "$PLACEHOLDER" "
  (\$page | [match(\"<script>\"; \"g\")] | length) as \$n
  | if \$n != 1 then error(\"page must contain exactly one <script> block, found \\(\$n)\") else . end
  | (\$page | index(\"<script>\")) as \$s0
  | (\$page | index(\"</script>\")) as \$s1
  | (\$page[0:\$s0] + \$page[\$s1 + 9:]) as \$markup
  | (\$page[\$s0 + 8:\$s1]) as \$code
  | if ($PANEL_OPTS.afterRender | contains(\$ph)) then . else error(\"placeholder \\(\$ph) missing in template afterRender\") end
  | $PANEL_OPTS.afterRender |= sub(\"/\\\\*@@PAGE@@\\\\*/\"; \"const HTML = \\(\$markup | tojson);\nconst CODE = \\(\$code | tojson);\")
" "$TEMPLATE" > "$OUT.tmp"
mv "$OUT.tmp" "$OUT"

echo "wrote $OUT ($(wc -c < "$OUT") bytes) from $PAGE + $TEMPLATE"
