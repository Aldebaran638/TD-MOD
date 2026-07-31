-- 统一武器数据表
-- 将多个武器的参数放在一起，便于维护与扩展

weaponData = weaponData or {}

#include "schema.lua"
#include "x/tachyon_lance.lua"
#include "x/focused_arc_emitter.lua"
#include "x/giga_cannon.lua"
#include "l/large_gamma_laser.lua"
#include "l/large_plasma_cannon.lua"
#include "l/large_gauss_cannon.lua"
#include "l/kinetic_artillery.lua"
#include "l/large_stormfire_autocannon.lua"
#include "m/medium_gamma_laser.lua"
#include "m/medium_plasma_cannon.lua"
#include "m/phase_disruptor.lua"
#include "m/medium_gauss_cannon.lua"
#include "m/medium_stormfire_autocannon.lua"
#include "m/swarmer_missile.lua"
#include "g/devastator_torpedoes.lua"
#include "g/neutron_launcher.lua"
#include "h/gamma_strike_craft.lua"
#include "p/flak_artillery.lua"
#include "p/guardian_point_defense.lua"

-- 可以在此处继续添加更多武器配置，例如：
