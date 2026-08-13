-- CM2 GENERATED FILE; DO NOT EDIT.
-- Source: Content Mod 2 Definition Compiler MVP.
-- Input SHA-256: 757a31402a40257da8feffb9a6608a7e9ed632f245e0494625eb198931ed648a
return {
  ["cm2:slice.effect.guided"]={id="cm2:slice.effect.guided",kind="effect",runtime={assetId="cm2:slice.asset.guided",effectType="trail",priority=50},schemaVersion="cm2.effect/1"},
  ["cm2:slice.projectile.guided"]={id="cm2:slice.projectile.guided",kind="projectile",runtime={damage=195,effectId="cm2:slice.effect.guided",speedMps=155},schemaVersion="cm2.projectile/1"},
  ["cm2:slice.weapon.guided"]={id="cm2:slice.weapon.guided",kind="weapon",runtime={behavior="guided",effectId="cm2:slice.effect.guided",fireRateHz=0.2,projectileId="cm2:slice.projectile.guided"},schemaVersion="cm2.weapon/1"}
}
