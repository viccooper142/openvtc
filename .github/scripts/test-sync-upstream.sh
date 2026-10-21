#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
sync_script="$repo_root/.github/scripts/sync-upstream.sh"

fail() {
  printf 'FAIL sync-upstream regression: %s\n' "$*" >&2
  exit 1
}

[[ -x "$sync_script" ]] || fail "production sync script is missing or not executable"

fixture_root="$(mktemp -d)"
trap 'rm -rf "$fixture_root"' EXIT

git init --bare --initial-branch=main "$fixture_root/upstream.git" >/dev/null
git clone "$fixture_root/upstream.git" "$fixture_root/upstream-work" >/dev/null 2>&1
git -C "$fixture_root/upstream-work" config user.name fixture-upstream
git -C "$fixture_root/upstream-work" config user.email fixture-upstream@example.invalid
mkdir -p "$fixture_root/upstream-work/.github/workflows"
printf 'base source\n' > "$fixture_root/upstream-work/source.txt"
printf 'upstream base workflow\n' > "$fixture_root/upstream-work/.github/workflows/ci.yml"
git -C "$fixture_root/upstream-work" add source.txt .github/workflows/ci.yml
git -C "$fixture_root/upstream-work" commit -m 'fixture: base' >/dev/null
git -C "$fixture_root/upstream-work" push origin main >/dev/null 2>&1

git clone "$fixture_root/upstream.git" "$fixture_root/fork-work" >/dev/null 2>&1
git -C "$fixture_root/fork-work" config user.name fixture-fork
git -C "$fixture_root/fork-work" config user.email fixture-fork@example.invalid
mkdir -p "$fixture_root/fork-work/.github/scripts"
printf 'fork controlled workflow\n' > "$fixture_root/fork-work/.github/workflows/ci.yml"
printf '# fork controlled helper\n' > "$fixture_root/fork-work/.github/scripts/local-helper.sh"
git -C "$fixture_root/fork-work" add .github
git -C "$fixture_root/fork-work" commit -m 'fixture: fork controls automation' >/dev/null

printf 'upstream source after fork\n' > "$fixture_root/upstream-work/source.txt"
printf 'upstream changed workflow\n' > "$fixture_root/upstream-work/.github/workflows/ci.yml"
printf 'upstream new workflow\n' > "$fixture_root/upstream-work/.github/workflows/release.yml"
printf '# upstream automation helper\n' > "$fixture_root/upstream-work/.github/untrusted-helper.sh"
git -C "$fixture_root/upstream-work" add source.txt .github
git -C "$fixture_root/upstream-work" commit -m 'fixture: source and automation advance' >/dev/null
git -C "$fixture_root/upstream-work" push origin main >/dev/null 2>&1

before_github_tree="$(git -C "$fixture_root/fork-work" rev-parse HEAD:.github)"

git -C "$fixture_root/fork-work" remote rename origin fork-origin
(
  cd "$fixture_root/fork-work"
  "$sync_script" "$fixture_root/upstream.git" main
)

after_github_tree="$(git -C "$fixture_root/fork-work" rev-parse HEAD:.github)"
[[ "$after_github_tree" == "$before_github_tree" ]] ||
  fail "the sync changed fork-controlled .github automation"

upstream_head="$(git -C "$fixture_root/upstream-work" rev-parse HEAD)"
git -C "$fixture_root/fork-work" merge-base --is-ancestor "$upstream_head" HEAD ||
  fail "the synced fork does not contain the upstream source commit"

[[ "$(git -C "$fixture_root/fork-work" show HEAD:source.txt)" == 'upstream source after fork' ]] ||
  fail "upstream source content did not land"

[[ "$(git -C "$fixture_root/fork-work" show HEAD:.github/workflows/ci.yml)" == 'fork controlled workflow' ]] ||
  fail "the fork workflow was not preserved"

if git -C "$fixture_root/fork-work" cat-file -e HEAD:.github/workflows/release.yml 2>/dev/null; then
  fail "an upstream workflow was imported"
fi

if git -C "$fixture_root/fork-work" cat-file -e HEAD:.github/untrusted-helper.sh 2>/dev/null; then
  fail "an upstream automation helper was imported"
fi

[[ "$(git -C "$fixture_root/fork-work" show -s --format=%P HEAD | wc -w | tr -d ' ')" == '2' ]] ||
  fail "the sync did not preserve continuity with a merge commit"

printf 'PASS sync-upstream preserves fork automation and merges upstream source\n'
