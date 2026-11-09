#!/usr/bin/env bash
set -euo pipefail

readonly GITHUB_USER="nxhung2304"
readonly EXCLUDED_OWNERS=("NaraOrganization" "hqlg")
readonly README_PATH="README.md"
readonly SEARCH_PAGE_SIZE=100
readonly START_MARKER="<!-- contributions:start -->"
readonly END_MARKER="<!-- contributions:end -->"

build_search_query() {
  local query="is:pr author:${GITHUB_USER} -user:${GITHUB_USER}"
  local owner
  for owner in "${EXCLUDED_OWNERS[@]}"; do
    query+=" -user:${owner}"
  done
  echo "$query"
}

fetch_contribution_lines() {
  local search_query=$1
  gh api -X GET search/issues \
    -f q="$search_query" \
    -f sort=created \
    -f order=desc \
    -f per_page="$SEARCH_PAGE_SIZE" \
    --jq '
      .items[]
      | select(.state == "open" or .pull_request.merged_at != null)
      | (.repository_url | sub(".*/repos/"; "")) as $repo
      | (if .state == "open" then "open" else "merged" end) as $status
      | "- [\($repo)#\(.number)](\(.html_url)): \(.title) (\($status))"
    '
}

build_updated_readme() {
  local contribution_lines=$1
  CONTRIBUTION_LINES="$contribution_lines" awk \
    -v start="$START_MARKER" \
    -v end="$END_MARKER" '
      $0 == start { print; if (ENVIRON["CONTRIBUTION_LINES"] != "") print ENVIRON["CONTRIBUTION_LINES"]; is_inside_block = 1; next }
      $0 == end { is_inside_block = 0 }
      !is_inside_block { print }
    ' "$README_PATH"
}

main() {
  if ! grep -qxF "$START_MARKER" "$README_PATH" || ! grep -qxF "$END_MARKER" "$README_PATH"; then
    echo "Markers not found in ${README_PATH}" >&2
    exit 1
  fi

  local search_query contribution_lines updated_readme
  search_query=$(build_search_query)
  contribution_lines=$(fetch_contribution_lines "$search_query")
  updated_readme=$(build_updated_readme "$contribution_lines")
  printf '%s\n' "$updated_readme" > "$README_PATH"
}

main "$@"
