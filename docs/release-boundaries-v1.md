# Release Artifacts and Support Boundaries v1

## Packages

The platform is distributed as independent artifacts: Core Runtime; Creator CLI/Compiler; External Editor; Preview Mod; Schema/API documentation; Templates/Examples; Conformance Test Kit; and an optional AI provider integration. The dependency graph and exact source roots are in `docs/release-artifacts-v1.json`. Every artifact has its own version, compatibility scope, install instruction and support boundary.

Core Runtime is the player-facing minimum. It does not depend on Editor, AI or DCC tools. The Creator CLI/Compiler can build data-only packages without Editor or AI. The Editor is an optional authoring surface, Preview is an optional creator tool, and AI is removable and never produces Runtime Lua. Templates and the Conformance Kit are optional authoring/release aids.

## Required documentation

The support set covers: a five-minute first weapon; importing a single-body VOX; ID, coordinate, Anchor and Turret rules; Effect, Projectile and Joint budgets; the Schema/Core/SDK compatibility matrix; stable error codes; release, upgrade, rollback and uninstall; Data-only versus Expert Behavior boundaries; and AI asset provenance/license requirements.

Canonical topic labels for the support checker are: five-minute weapon; single-body VOX; ID coordinate Anchor Turret; Effect Projectile Joint budget; compatibility matrix; error codes; release upgrade rollback uninstall; Data-only Expert Behavior; AI provenance license.

## Clean-room profiles

The fixture defines four install profiles: Core-only player runtime, CLI without Editor/AI, Editor without AI, and Conformance. Each profile states installed and removed artifacts so support claims remain testable. Download content is source-root based in this repository; release promotion must replace those references with immutable archive hashes and verify them before publication.

## Current boundary

The manifest, dependency DAG, documentation coverage and clean-room contract are verified headlessly. A real Core-only Teardown run and archive/download verification are deferred until Teardown and release packaging infrastructure are available; the current gate is therefore an honest headless candidate.

## Rollback

Keep the previous single-package Framework manifest as an internal fallback, preserve artifact hashes and restore the last valid Core package if a split package fails. Removing optional Editor/AI packages must not remove Core/CLI/Schema functionality.
