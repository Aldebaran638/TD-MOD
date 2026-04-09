-- 统一武器数据表
-- 将多个武器的参数放在一起，便于维护与扩展

weaponData = weaponData or {}

#include "weapons/xSlots/tachyonLance.lua"
#include "weapons/lSlots/kineticArtillery.lua"
#include "weapons/sSlots/swarmerMissile.lua"
#include "weapons/sSlots/devastatorTorpedoes.lua"
#include "weapons/hSlots/gammaStrikeCraft.lua"

-- 可以在此处继续添加更多武器配置，例如：
-- weaponData.plasmaCannon = { ... }
