# Vehicle platform cutover v1 (Step 6.7)

The five current definitions are now represented by one cutover ledger:

`advancedStrikeCraft`, `advancedSwarmerMissile`, `devastatorTorpedo`,
`battlecruiser`, and `titan`.

For every entry the declared ownership is:

`VehicleFactory → EntityGraph → Transform/AnchorResolver`,

with `rootBodyAuthority=adapter-only`. `cm2VehiclePlatformCutoverV1` registers
all five, records legacy/shadow/anchor mode, requires a clean comparison before
anchor promotion, and stores rollback reasons. Both ship entry points initialize
the ledger in legacy-safe mode; this makes the ownership boundary explicit while
preserving the current single-Body runtime until live evidence is available.

The repository still contains direct Body/vehicle reads in movement, camera,
thruster, weapon, presentation, damage and network paths. They are not silently
deleted in this step. The fixture's legacy-reader ledger records those categories
under the policy `legacy-readers-allowed-only-through-ADR-until-live-S0-S7`.
Those reads are the remaining migration debt; the only authority permitted for a
new path is the adapter DTO. Step 6.4's batch facade is the controlled route for
removing each allowlist entry.

The offline runner proves five registrations, five clean comparisons, shadow
mode for all five, one guarded anchor promotion followed by rollback, unknown
vehicle and stale-handle rejection, and reports the current legacy-reader file
count. The self-test rejects promotion before comparison and an incomplete
five-Vehicle ledger.

Rollback is per Vehicle: restore its mode to legacy, keep the comparison and
reason, and leave the existing VehicleInstance/ship adapter path intact. Live
S0-S7 behavior, root-authority scan in a running world, and final deletion of
legacy reads require a discoverable Teardown executable and a later gate.
