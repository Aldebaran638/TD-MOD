# PackageManifest v1 / Data-only Capability

`tools/cm2-package/run-package-manifest-v1.ps1` defines and validates the first
extension boundary. A manifest contains package ID/version, schema/Core/SDK
ranges, build format, display/author/license/provenance, source content entries,
asset entries, generated-data hashes, required/optional dependencies,
capabilities, entrypoints, budgets, files, a dependency graph and a lock.

V1 is explicitly data-only. The allow-list is Ship, Mount, Turret, Weapon,
Projectile, Effect, Localization and Assets. Every package-owned ID is
namespaced; source URIs use `pkg://<packageId>/...`; traversal, absolute paths,
duplicate IDs, unknown capabilities and `.lua` files are rejected. Required
dependencies must be present in the lock with matching hashes, and the graph is
cycle-checked before Compiler/build. Body/Shape/Joint/package-byte budgets are
checked at the same boundary.

The signature is a deterministic SHA-256 fingerprint over the canonical manifest
with the signature value blanked. Package artifact/manifest hash is computed from
canonical manifest + dependency graph + lock (`self` is used for the package's
own lock slot so hashing is not self-referential). The result is therefore
reproducible and can later be replaced by a real signing service without changing
the data contract. The runner checks the existing Definition Compiler's schema,
runtime projection and generated-manual-edit policy as the capability bridge.

The negative suite covers missing dependency, dependency cycle, duplicate ID,
unsafe path, unknown capability, Runtime Lua entrypoint, budget overflow, asset
hash mismatch, future schema and signature mismatch. Every error shape includes
package/definition/field context and a repair suggestion. Runtime fallback is
builtin-only; an unknown package is never loaded as Lua. Rollback is to allow
builtin packages only and retain the previous manifest/lock/package artifact.

No Teardown executable is available on this machine, so install/live Runtime
evidence is deferred; this step proves the pre-build security and reproducibility
boundary only.
