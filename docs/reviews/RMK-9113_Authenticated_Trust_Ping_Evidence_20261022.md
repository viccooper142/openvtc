# RMK-9113 authenticated trust-ping evidence

Date: 2026-10-22

Candidate branch: `codex/rmk-9113-authenticated-trust-ping-main`

Base: `fa36fe698e6c212d7476691a1f5b6b03f5641b2a` (`origin/main`)

## Security behavior

The trust-ping responder now authorizes the transport-authenticated DID rather
than the plaintext `from` header:

- live DIDComm uses the SDK `ReceivedMessage.sender`, which SDK 0.37 sets only
  after exact equality between plaintext `from` and the DID before `#` in
  `encrypted_from_kid`;
- stored DIDComm derives the DID before the single non-empty key fragment from
  `UnpackMetadata.encrypted_from_kid` and requires exact equality with `from`;
- anoncrypt, missing senders, sender mismatches, and TSP trust-pings are rejected;
- the authenticated DID must be either the exact configured mediator DID or an
  established relationship DID;
- replay state is isolated from general messages, updated only after
  authorization, and scoped by authenticated sender plus message ID;
- a successful pong retains the ping ID as `thid` and is addressed only to the
  authenticated sender.

No cryptographic implementation, key representation, or private-key material
is added or changed. The patch consumes the OpenVTC/VTI DIDComm unpack result.

## Red-before-green evidence

The regression tests were authored before the product change. A detached
fixture at the exact base adds only the event-seam contract test
`trust_ping_event_carries_authenticated_sender_and_transport`. The unpatched
source fails to compile that test because `TrustPingReceived` has no
`authenticated` or `transport` fields. This is the missing wiring that allowed
the state handler to authorize only plaintext `from`.

Red command on Ross:

```text
cargo test --locked -p openvtc-core --no-default-features \
  trust_ping_event_carries_authenticated_sender_and_transport
```

Observed result: **FAIL** with Rust `E0026` because
`DIDCommEvent::TrustPingReceived` did not have fields named `authenticated` and
`transport`.

The corresponding green candidate test is
`trust_ping_classification_forwards_bound_sender_and_transport`.

## Verification

Executed in a source-only temporary snapshot on Ross using Rust 1.95 and two
build jobs. No OpenVTC service, identity, listener, database, credential, or
production setting was activated.

- `cargo test --locked -p openvtc-core --no-default-features trust_ping_`:
  **PASS**, 7 tests.
- Focused no-default-features pong correlation test: **PASS**, 1 test.
- Before the final test-only hardening,
  `cargo test --locked --workspace --no-default-features --quiet` **PASS**ed,
  including 996 OpenVTC and 1052 core tests plus integrations and doctests.
  On the final candidate, 995/996 OpenVTC tests passed in the full rerun; the
  unrelated live-theme file-watcher test failed at its edit notification and
  then **PASS**ed immediately in an isolated exact rerun. All 7 changed
  trust-ping tests passed on the final candidate.
- `cargo test --locked --workspace --quiet`: all unit and integration suites
  passed; two concurrent large doctest link steps initially ended in an `lld`
  `SIGBUS`. After clearing the task build cache, a one-build-job, one-test-thread
  retry of the `openvtc-core` doctests **PASS**ed all 3 doctests.
- `cargo fmt --all -- --check`: **PASS**.
- `cargo clippy --locked --workspace --all-targets` on the final candidate:
  **PASS** with `-D warnings` after allowing only the two pre-existing lint
  classes (`nonminimal-bool`, `collapsible-match`) in unchanged `join.rs`,
  `health_cmd.rs`, and `join_flow.rs`.

The 78.74 GB task-specific target cache was removed after the capacity failure,
returning Ross from 100% root usage to 27%. The cache contained only recreatable
Rust build artifacts.

## Independent review

Reviewer: Claude Opus 5.5, isolated subscription session
`f082d880-b3d0-48c4-9d87-875b8d22d5f2`. The reviewer did not read source with
tools; the complete candidate diff and the unchanged seam excerpts were supplied
in the review prompts. MCP servers, skills, and plugins were disabled.

The fresh current-main review found no blocking correctness, security,
regression, or acceptance-criteria defect and returned `VERDICT: APPROVE`,
conditional on supplying three unchanged seams that were not present in the
candidate diff. They were then checked directly:

1. `affinidi-messaging-sdk` 0.37 `to_inbound` sets
   `ReceivedMessage.sender = authenticated_sender(message, meta)`. That helper
   requires authenticated, non-anonymous metadata, an `encrypted_from_kid` DID
   URL containing `#`, and exact equality between plaintext `from` and the DID
   before `#`. Unlike the stricter pickup check, SDK 0.37 does not itself require
   a non-empty fragment, reject a second `#`, or separately inspect `encrypted`.
   The reviewer found that divergence non-exploitable because the resolved
   authcrypt key still binds the exact DID and the local policy rejects an empty
   authenticated DID.
2. `Messaging::pickup_stored` passes the `frame_to_message` authenticated sender
   as both claimed and authenticated inputs to the shared `classify_inbound`.
3. Workspace searches for both trust-ping and trust-pong forms show one inbound
   trust-ping responder: the guarded state-handler arm. Searches across the SDK,
   delivery, and DIDComm dependency crates find the SDK
   `protocols/trust_ping.rs` surface that sends a ping or explicitly constructs
   a pong; it does not automatically answer an inbound ping.

The reviewer also identified useful test hardening. Before final review, the
candidate was strengthened to assert each exact rejection reason, cover a
relationship key spoofing the mediator DID, cover encrypted/authenticated/
anonymous metadata flags, missing `from`, empty and double fragments, DID prefix
extension, and the pickup-to-classification sender path. All 7 focused tests
pass after those additions.

The follow-up reviewed the supplied unchanged seams plus the strengthened
test/evidence diff and concluded that this qualifies as the independent
current-main review. Final verdict: **APPROVE**. Remaining non-blocking gaps are
an integration test through the real state-handler relationship store, a test
through the asynchronous `pickup_stored` function itself, and a state-handler
pong-destination integration test.

## Delivery and activation state

This is source and test work only. It does not activate Ross or Palo, expose a
public endpoint, promote trust, or use real identity material. Merge remains a
human gate. RMRKBL re-pinning and any staged/live DIDComm exercise are separate
reviewed changes.
