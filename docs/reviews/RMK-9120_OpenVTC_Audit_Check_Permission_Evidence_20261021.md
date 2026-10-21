# RMK-9120 OpenVTC audit-check permission evidence

Date: 2026-10-21

Candidate base: `171acd14819c5609551687be30ff63df71bfb459`

## Scope

RMK-9120 repairs only the GitHub check-publishing permission for the existing
`Security Audit` job. It does not change application source, dependencies,
repository-wide permissions, identities, credentials, deployment, or Ross.
No personal access token is introduced.

## Production failure evidence

The post-merge `main` workflow run for OpenVTC PR #2 was GitHub Actions run
`39675452325`, attempt 2, at merge commit
`171acd14819c5609551687be30ff63df71bfb459`. Eleven jobs succeeded. The
`Security Audit` job completed its RustSec scan with zero vulnerabilities and
the accepted `RUSTSEC-2026-0173` unmaintained warning, then failed while
creating its GitHub check run:

```text
Resource not accessible by integration
```

The job's `GITHUB_TOKEN` permissions listed `Contents: read`, `Metadata: read`,
and `Packages: read`; it did not have `Checks: write`. The repository default is
read-only workflow permissions. The pull-request version of the same action
downgraded the publishing failure to a warning, which explains why the PR job
appeared green while the push-to-`main` job failed.

The `rustsec/audit-check` v2 documentation identifies `checks: write` as the
granular permission used to create a check. Its separate `issues: write`
permission is for scheduled issue creation and is not needed by this
push/pull-request workflow.

## Failing-first evidence

Before the candidate change, a structure-aware YAML assertion required the
`audit` job's permission map to equal exactly:

```yaml
contents: read
checks: write
```

It exited 1 with:

```text
FAIL: audit permissions=nil; expected {"contents"=>"read", "checks"=>"write"}
```

## Candidate change

The candidate adds only this job-level map to `.github/workflows/ci.yml`:

```yaml
permissions:
  contents: read
  checks: write
```

Keeping the map at job scope prevents the permission from being inherited by
the other CI jobs. Supplying an explicit map also makes every unlisted
permission `none` for this job. `contents: read` preserves checkout access and
`checks: write` permits the audit action to publish the result produced by its
existing scan.

## Verification contract

Before merge, the exact candidate head must pass:

- the YAML assertion above, including an assertion that no workflow-level
  `permissions` map exists;
- YAML parsing and `git diff --check`;
- independent Claude review of ambition, tests/seams, and wiring;
- the native pull-request CI matrix.

After merge, completion requires:

1. the independently reviewed commit is an ancestor of `origin/main`;
2. the `main` Security Audit job has `Checks: write` and succeeds;
3. its scan still reports zero vulnerabilities and only the accepted
   `RUSTSEC-2026-0173` unmaintained warning; and
4. all other `main` CI jobs succeed. A runner cancellation is missing evidence,
   not success.
