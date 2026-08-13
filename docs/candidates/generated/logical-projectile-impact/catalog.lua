-- CM2 GENERATED FILE; DO NOT EDIT.
-- Source: Content Mod 2 Definition Compiler MVP.
-- Input SHA-256: 8e7db2dbac17862c38ae4ed7ea0a2947412f74406a8a2ca71ce17ea8bc5924cb
return {
  ["cm2:slice.effect.impact"]={id="cm2:slice.effect.impact",kind="effect",runtime={assetId="cm2:slice.asset.impact",effectType="impact",priority=55},schemaVersion="cm2.effect/1"},
  ["cm2:slice.projectile.logical"]={id="cm2:slice.projectile.logical",kind="projectile",runtime={damage=2600,effectId="cm2:slice.effect.impact",speedMps=560},schemaVersion="cm2.projectile/1"},
  ["cm2:slice.weapon.projectile"]={id="cm2:slice.weapon.projectile",kind="weapon",runtime={behavior="ballistic",effectId="cm2:slice.effect.impact",fireRateHz=0.5,projectileId="cm2:slice.projectile.logical"},schemaVersion="cm2.weapon/1"}
}
