# RMK-9114 OpenVTC RustSec drift remediation evidence

Date: 2026-10-21

Candidate base: `613ab52642537e1505e015b9987422d927be420c`

## Scope

RMK-9114 remediates the two residual RustSec vulnerabilities present after the
continuity sync from upstream OpenVTC. It does not change application source,
runtime configuration, identities, credentials, mediators, Valkey, deployment,
or Ross.

## Failing-first evidence

The synchronized base was checked in an official `rust:1.95` container with
`cargo-audit 0.22.2` and `cargo-deny 0.20.2`. The RustSec advisory database was
at commit `4b587f00996ebe5c05a73eaef105ef241e876414`, updated
`2026-10-21T08:20:38+02:00`.

`cargo audit` exited non-zero with exactly two vulnerabilities:

| Advisory | Locked crate | Required patched version | Disposition |
| --- | --- | --- | --- |
| `RUSTSEC-2026-0382` | `rustls-webpki 0.103.15` | `>= 0.103.16` | update to `0.103.16` |
| `RUSTSEC-2026-0383` | `webpki-root-certs 1.0.9` | `>= 1.0.10` | update to `1.0.10` |

The exact CI Cargo Deny command also exited non-zero on those two advisories:

```text
cargo deny --log-level warn --manifest-path ./Cargo.toml --all-features \
  check advisories licenses bans sources
```

Its other sections were already green: bans, licenses, and sources. The check
also reported that the configured `RUSTSEC-2024-0436` exception no longer
matched any dependency after the continuity sync.

## Candidate changes

- Update `rustls-webpki` from `0.103.15` to `0.103.16` in `Cargo.lock`.
- Update `webpki-root-certs` from `1.0.9` to `1.0.10` in `Cargo.lock`.
- Accept Cargo's required resolver adjustment for `tempfile 3.27.0`, selecting
  its already-locked `getrandom 0.3.4` entry instead of `getrandom 0.4.3`.
- Remove only the stale `RUSTSEC-2024-0436` Cargo Deny exception.

No new advisory ignore, license exception, dependency manifest constraint, or
application-code change is introduced. The existing documented exceptions for
`RUSTSEC-2023-0071` and `RUSTSEC-2026-0173` are unchanged and are outside the
newly discovered vulnerability set.

## Local verification

The following checks passed against the candidate:

- `cargo metadata --locked --format-version 1`
- `cargo audit` — zero vulnerabilities; the pre-existing accepted
  `proc-macro-error2` unmaintained warning remains
- the exact four-section Cargo Deny invocation above — advisories, bans,
  licenses, and sources all `ok`
- `cargo fmt --all --check`
- `git diff --check`

An attempted fresh-container `cargo check --workspace --locked` reached the
large all-features `trust-tasks-rs` compile but was stopped after the local ARM
Docker VM ceased responding to status queries. It produced no compiler error,
but it is not counted as a pass. The native GitHub Linux/MSRV, Clippy, test,
documentation, benchmark, audit, and Cargo Deny jobs are therefore required
PR gates.

## Independent-review questions

The reviewer should verify all three legs of the project review standard:

1. **Ambition beyond the diff:** Does this candidate remove the complete new
   RustSec exposure without hiding risk or broadening scope?
2. **Tests and seams:** Do the failing-first and post-change audit/deny results,
   plus the native CI matrix, adequately exercise the transitive TLS trust
   path and the supported Rust 1.95 lockfile?
3. **Wiring proof:** Are the patched versions the ones actually selected by the
   locked workspace, and do both GitHub security jobs run on the PR and on
   `main`?

## Merge and live gate

This item is not complete at PR creation. After an independent reviewer finds
no blocking problem and merge is explicitly authorized, completion requires:

1. the candidate commit is an ancestor of `origin/main`;
2. the GitHub `Security Audit` and `Cargo Deny` jobs are green on `main`;
3. the remaining required CI jobs are green, with any runner cancellation
   treated as missing evidence rather than success; and
4. the result is recorded in the native RMK-9114 work item.
