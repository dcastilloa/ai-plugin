#!/usr/bin/env bash
#
# Validates the PostHog AI Plugin's definition files so a Cloud Agent (or a
# contributor) can confirm the plugin is coherent before it is loaded into an
# AI coding tool or published to a marketplace.
#
# This repository has no build step or dependencies: it is a set of JSON
# manifests plus markdown command/agent/skill definitions. "Validation" here
# means the manifests parse, referenced assets exist, and every markdown
# definition carries YAML frontmatter. The script is idempotent and offline.
set -euo pipefail

cd "$(dirname "$0")/.."

fail() { echo "FAIL: $*" >&2; exit 1; }

command -v jq >/dev/null 2>&1 || fail "jq is required but not installed"

echo "==> Validating JSON manifests"
json_files=(
  ".claude-plugin/plugin.json"
  ".cursor-plugin/plugin.json"
  "mcp.json"
  ".mcp.json"
)
for f in "${json_files[@]}"; do
  [ -f "$f" ] || fail "missing required file: $f"
  jq -e . "$f" >/dev/null || fail "invalid JSON: $f"
  echo "    ok  $f"
done

echo "==> Checking plugin manifest required fields"
for f in ".claude-plugin/plugin.json" ".cursor-plugin/plugin.json"; do
  for key in name version description; do
    val=$(jq -r --arg k "$key" '.[$k] // empty' "$f")
    [ -n "$val" ] || fail "$f is missing required field: $key"
  done
  echo "    ok  $f (name/version/description present)"
done

echo "==> Checking MCP server configuration"
for f in "mcp.json" ".mcp.json"; do
  url=$(jq -r '.mcpServers.posthog.url // empty' "$f")
  [ -n "$url" ] || fail "$f is missing mcpServers.posthog.url"
  echo "    ok  $f -> $url"
done

echo "==> Checking referenced assets exist"
logo=$(jq -r '.logo // empty' ".cursor-plugin/plugin.json")
if [ -n "$logo" ]; then
  [ -f "$logo" ] || fail "logo referenced in .cursor-plugin/plugin.json not found: $logo"
  echo "    ok  logo asset: $logo"
fi

echo "==> Checking markdown definitions have frontmatter"
md_count=0
for f in commands/*.md agents/*.md skills/*/SKILL.md; do
  [ -e "$f" ] || continue
  [ "$(head -1 "$f")" = "---" ] || fail "$f is missing YAML frontmatter (must start with '---')"
  md_count=$((md_count + 1))
done
[ "$md_count" -gt 0 ] || fail "no markdown command/agent/skill definitions found"
echo "    ok  $md_count markdown definition(s) validated"

echo
echo "Plugin validation passed."
