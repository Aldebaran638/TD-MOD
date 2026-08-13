# PackageManifest v1 / Data-only Capability

`schemas/cm2/package-manifest-v1.json` and
`tools/cm2-package/run-package-manifest-v1.ps1` define and validate the first
extension boundary. A manifest contains package ID/version, schema/Core/SDK
ranges, build format, display/author/license/provenance, source content entries,
asset entries, generated-data hashes, required/optional dependencies,
capabilities, entrypoints, budgets, files, a dependency graph and a lock.

V1 is explicitly data-only. The allow-list is Ship, Mount, Turret, Weapon,
Projectile, Effect, Localization and Assets. Every package-owned ID is
namespaced; source URIs use `pkg://<packageId>/...`; traversal, absolute paths,
duplicate IDs, unknown capabilities and `.lua` files are rejected. Required
dependencies must be present in the lock with matching hashes, and the graph is
cycle-checked before Compiler/build. The resolved Core API, SDK and dependency
versions must satisfy their declared semantic-version ranges. Body/Shape/Joint/
package-byte budgets are checked at the same boundary.

The signature is a deterministic SHA-256 fingerprint over the canonical manifest
with the signature value blanked. Package artifact/manifest hash is computed from
the emitted `cm2.package-artifact/1` bytes containing canonical manifest +
dependency graph + lock (`self` is used for the package's
own lock slot so hashing is not self-referential). The result is therefore
reproducible and can later be replaced by a real signing service without changing
the data contract. The reported artifact hash is recalculated from the file bytes.
The capability bridge maps `Ship/Mount/Turret/Weapon/Projectile/Effect` to the
shared Definition Compiler schema kinds and treats `Localization/Assets` as
resource-only capabilities. The public schema, validator allow-list and fixture
must agree.

The negative suite covers missing dependency, dependency cycle, duplicate ID,
unsafe path, unknown capability, Runtime Lua entrypoint, budget overflow, asset
hash mismatch, future schema, incompatible Core API, SDK and dependency versions,
and signature mismatch. Every error shape includes package/definition/field
context and a repair suggestion. Runtime fallback is
builtin-only; an unknown package is never loaded as Lua. Rollback is to allow
builtin packages only and retain the previous manifest/lock/package artifact.

`install-package-consumer-v1.ps1` installs the artifact twice into the independent
`_AI Test Consumer Basic` Mod, projects only signed data decisions into its XML
script parameters, accepts `Ship`, and rejects `ExecuteLua`. The package tree must
contain no Lua; the consumer host must not include/load CM2 private files. Reopen
Teardown's Mod Manager after installing or changing metadata, then start the Mod
to prove the installed public data contract is readable. This Step does not claim
that the generated ship/weapon runs in CM2: that full clean-room Runtime chain is
owned by Step 9.3.
