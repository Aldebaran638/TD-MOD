-- 统一武器数据表
-- 将多个武器的参数放在一起，便于维护与扩展

weaponData = weaponData or {}

#include "x/tachyon_lance.lua"
#include "l/kinetic_artillery.lua"
#include "m/swarmer_missile.lua"
#include "g/devastator_torpedoes.lua"
#include "h/gamma_strike_craft.lua"

-- 可以在此处继续添加更多武器配置，例如：
-- weaponData.plasmaCannon = { ... }
