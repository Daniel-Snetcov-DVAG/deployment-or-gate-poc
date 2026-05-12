#!/usr/bin/env bash

set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "usage: $0 <owner/repo>" >&2
  exit 1
fi

repo="$1"

for environment in entwicklung d01 d02 d03 d04 d05; do
  gh api \
    --method PUT \
    -H "Accept: application/vnd.github+json" \
    "repos/${repo}/environments/${environment}" \
    >/dev/null
  echo "created or updated environment: ${environment}"
done

cat <<'EOF'

Next manual step in GitHub:

1. Open repository settings.
2. Configure branch protection or rulesets for `main`.
3. Require the CI job check.
4. Require the `pre-dev-deployment` status check.
5. Do not use GitHub's native required deployment selection for this scenario.

EOF
