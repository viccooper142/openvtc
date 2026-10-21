# RMK-9112 OpenVTC continuity-sync review

Date: 2026-10-21

Candidate reviewed: `e3a780ffbd6af2373eaf26b96837c842cf44965d`

Reviewer model: `claude-opus-5-5` through the logged-in Claude subscription

## Qualification

This review is advisory and **does not qualify as the independent review required
for merge**. The reviewer had zero tools, MCP servers, and skills, but its init
event still reported three built-in Claude Code plugins:

- `cc-plugin-agents-md`
- `cc-plugin-telemetry`
- `cc-plugin-plugin-authoring`

Claude Code `--safe-mode` leaves built-in plugins active. The repository review
procedure requires zero plugins, so the run must be treated as non-isolated even
though it returned a complete verdict.

## Advisory verdict

The reviewer returned `APPROVE`, conditional on a real post-merge
`workflow_dispatch` that performs and pushes a non-no-op upstream merge. It found
no material code defect in the candidate.

The reviewer traced these properties:

- the workflow uses only `github.token` with `contents: write`;
- the production script fails closed on conflicts outside `.github`;
- the complete fork-owned `.github` tree is restored before commit and checked
  both before and after commit;
- upstream ancestry and a two-parent merge are preserved;
- a concurrent `main` update makes the ordinary push fail closed;
- the regression test invokes the production script and detects loss of the
  `.github` isolation behavior.

## Non-blocking gaps identified

- The fail-first evidence proved the production script was missing; it did not
  include a mutation run with the isolation lines removed.
- The regression suite does not separately exercise a non-`.github` conflict or
  a clean merge that adds a new upstream workflow.
- The regression test is not itself wired into CI.
- `shellcheck` and `actionlint` were unavailable locally.
- The `actions/checkout` commit pin was not independently mapped to its release
  tag during the review.

## Required live gate

After a qualifying independent review and merge, Verified-live requires all of
the following from a manual dispatch on `main`:

1. The run logs a real merge, not `already current`.
2. The ordinary push succeeds and creates a two-parent commit on `main`.
3. The resulting `HEAD:.github` tree equals the pre-run tree.

If GitHub rejects the push because newly reachable upstream history contains
workflow-file changes, stop. Do not add a broad personal access token.
