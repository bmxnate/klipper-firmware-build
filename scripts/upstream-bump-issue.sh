#!/usr/bin/env bash
# Open a GitHub Issue (upstream-bump alert) for the check-upstream workflow.
# Invoked by .github/workflows/check-upstream.yaml — all inputs via env vars.
# Does NOT auto-bump; alert-only per maintainer's "Confirm First" rule.
set -eu

PINNED="${PINNED:?}"
PINNED_SHORT="${PINNED_SHORT:?}"
PINNED_DESC="${PINNED_DESC:?}"
UPSTREAM="${UPSTREAM:?}"
UPSTREAM_SHORT="${UPSTREAM_SHORT:?}"
UPSTREAM_SUBJECT="${UPSTREAM_SUBJECT:?}"
REPO="${GITHUB_REPOSITORY:?}"

# Skip if pin matches upstream (no-op success)
if [ "$PINNED" = "$UPSTREAM" ]; then
  echo "Pin matches upstream — no action."
  exit 0
fi

# Dedup: if an open issue already mentions this upstream SHA, skip
EXISTING=$(gh issue list \
  --repo "$REPO" \
  --state open \
  --search "upstream Klipper $UPSTREAM_SHORT in:title" \
  --json number,title \
  --jq '.[0].number // empty' 2>/dev/null || echo "")
if [ -n "${EXISTING:-}" ]; then
  echo "Issue #$EXISTING already open for upstream $UPSTREAM_SHORT. Skipping."
  exit 0
fi

# Try to fetch the upstream commit shallowly to count how many commits behind
git -C klipper fetch --depth=1 origin "$UPSTREAM" 2>/dev/null || true
COMMITS_BEHIND=$(git -C klipper rev-list --count "$PINNED..$UPSTREAM" 2>/dev/null || echo "unknown")

BODY=$(cat <<EOF
Upstream Klipper master has advanced since this repo's pinned submodule.

| | Short SHA | Description |
|---|---|---|
| **Pinned** | \`$PINNED_SHORT\` | $PINNED_DESC |
| **Upstream master** | \`$UPSTREAM_SHORT\` | $UPSTREAM_SUBJECT |

Commits behind upstream: **$COMMITS_BEHIND**

To bump the submodule and trigger a new build of all boards:

\`\`\`sh
cd ~/klipper-firmware-build/klipper
git fetch origin
git checkout $UPSTREAM  # $UPSTREAM_SHORT
cd ..
git add klipper
git commit -m "klipper: bump to $UPSTREAM_SHORT"
git push
\`\`\`

After the push, head to the Actions tab to watch the matrix run, then cut a release tag (\`v*\`) to publish the new \`firmware.bin\` artifacts for each board.

---

_This issue was opened automatically by the **check-upstream** workflow. Close it if you don't want to bump right now._

> SHA for dedup: \`$UPSTREAM\`
EOF
)

gh issue create \
  --repo "$REPO" \
  --title "klipper: upstream master advanced to ${UPSTREAM_SHORT} (pinned: ${PINNED_SHORT})" \
  --body "$BODY" \
  --label upstream-bump 2>&1 || gh issue create \
  --repo "$REPO" \
  --title "klipper: upstream master advanced to ${UPSTREAM_SHORT} (pinned: ${PINNED_SHORT})" \
  --body "$BODY"

echo "Issue created."
