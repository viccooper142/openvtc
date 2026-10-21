#!/usr/bin/env bash

set -euo pipefail

upstream_url="${1:?usage: sync-upstream.sh UPSTREAM_URL [BRANCH]}"
upstream_branch="${2:-main}"
upstream_remote="upstream"

starting_commit="$(git rev-parse --verify HEAD)"
starting_github_tree="$(git rev-parse "$starting_commit:.github")"

if git remote get-url "$upstream_remote" >/dev/null 2>&1; then
  git remote set-url "$upstream_remote" "$upstream_url"
else
  git remote add "$upstream_remote" "$upstream_url"
fi

git fetch --prune "$upstream_remote" "$upstream_branch"
upstream_ref="refs/remotes/$upstream_remote/$upstream_branch"

if git merge-base --is-ancestor "$upstream_ref" HEAD; then
  printf 'OpenVTC continuity fork is already current at %s\n' \
    "$(git rev-parse "$upstream_ref")"
  exit 0
fi

set +e
git merge --no-ff --no-commit "$upstream_ref"
merge_exit=$?
set -e

if [[ "$merge_exit" -ne 0 ]]; then
  unresolved="$(git diff --name-only --diff-filter=U)"
  outside_github="$(printf '%s\n' "$unresolved" | awk 'NF && $0 !~ /^\.github\//')"
  if [[ -z "$unresolved" || -n "$outside_github" ]]; then
    printf 'Refusing continuity sync with unresolved non-automation conflicts:\n%s\n' \
      "${outside_github:-<merge failed without reported conflicts>}" >&2
    git merge --abort
    exit 1
  fi
fi

# The continuity fork owns its automation.  Upstream source is merged, but
# upstream .github files are neither executed nor imported.  This also keeps
# the repository-scoped GITHUB_TOKEN sufficient: the pushed tip does not create,
# update, or delete workflow files.
git rm -r -f --ignore-unmatch .github >/dev/null
git checkout "$starting_commit" -- .github

unresolved="$(git diff --name-only --diff-filter=U)"
if [[ -n "$unresolved" ]]; then
  printf 'Refusing continuity sync with unresolved conflicts:\n%s\n' "$unresolved" >&2
  git merge --abort
  exit 1
fi

candidate_tree="$(git write-tree)"
candidate_github_tree="$(git rev-parse "$candidate_tree:.github")"
if [[ "$candidate_github_tree" != "$starting_github_tree" ]]; then
  printf 'Refusing continuity sync because fork automation changed\n' >&2
  git merge --abort
  exit 1
fi

git commit --no-edit

git merge-base --is-ancestor "$upstream_ref" HEAD || {
  printf 'Refusing continuity sync because the upstream commit is not an ancestor\n' >&2
  exit 1
}

final_github_tree="$(git rev-parse HEAD:.github)"
if [[ "$final_github_tree" != "$starting_github_tree" ]]; then
  printf 'Refusing continuity sync because committed fork automation changed\n' >&2
  exit 1
fi

printf 'Merged upstream source %s; preserved fork automation tree %s\n' \
  "$(git rev-parse "$upstream_ref")" "$final_github_tree"
