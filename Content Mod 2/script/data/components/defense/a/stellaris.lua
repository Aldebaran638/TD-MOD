---@diagnostic disable: undefined-global

shipComponentDefine({
    componentId = "advancedAfterburners", slotType = "auxiliary",
    displayName = "高级加力燃烧室", englishName = "Advanced Afterburners",
    iconPath = "MOD/gfx/ui/defense_components/advancedAfterburners.png",
    speedMultiplier = 0.20, turnResponseMultiplier = 0.50, turnForceMultiplier = 1.00,
    powerUse = 20.0,
})

shipComponentDefine({
    componentId = "shieldCapacitor", slotType = "auxiliary",
    displayName = "护盾电容", englishName = "Shield Capacitor",
    iconPath = "MOD/gfx/ui/defense_components/shieldCapacitor.png",
    shieldMultiplier = 0.10, powerUse = 20.0,
})

shipComponentDefine({
    componentId = "naniteRepairSystem", slotType = "auxiliary",
    displayName = "纳米修复系统", englishName = "Nanite Repair System",
    iconPath = "MOD/gfx/ui/defense_components/naniteRepairSystem.png",
    hullRegenPercent = 0.0015, armorRegenPercent = 0.0020, powerUse = 15.0,
})

shipComponentDefine({
    componentId = "advancedShieldHardener", slotType = "auxiliary",
    displayName = "高级护盾硬化器", englishName = "Advanced Shield Hardener",
    iconPath = "MOD/gfx/ui/defense_components/advancedShieldHardener.png",
    shieldHardening = 0.25, powerUse = 25.0,
})

shipComponentDefine({
    componentId = "livingReactiveArmor", slotType = "auxiliary",
    displayName = "活性反应装甲", englishName = "Living Reactive Armor",
    iconPath = "MOD/gfx/ui/defense_components/livingReactiveArmor.png",
    armorHardening = 0.25, powerUse = 25.0,
})

shipComponentDefine({
    componentId = "reactorBooster1", slotType = "auxiliary",
    displayName = "反应堆增压器 I", englishName = "Reactor Booster I",
    iconPath = "MOD/gfx/ui/defense_components/reactorBooster1.png",
    reactorOutputMultiplier = 0.20,
})

shipComponentDefine({
    componentId = "reactorBooster2", slotType = "auxiliary",
    displayName = "反应堆增压器 II", englishName = "Reactor Booster II",
    iconPath = "MOD/gfx/ui/defense_components/reactorBooster2.png",
    reactorOutputMultiplier = 0.33,
})

shipComponentDefine({
    componentId = "reactorBooster3", slotType = "auxiliary",
    displayName = "反应堆增压器 III", englishName = "Reactor Booster III",
    iconPath = "MOD/gfx/ui/defense_components/reactorBooster3.png",
    reactorOutputMultiplier = 0.50,
})

shipComponentDefine({
    componentId = "darkMatterCloakingField", slotType = "auxiliary",
    displayName = "暗物质隐形场", englishName = "Dark Matter Cloaking Field",
    iconPath = "MOD/gfx/ui/defense_components/darkMatterCloakingField.png",
    officialComponentId = "BATTLESHIP_CLOAKING_DARK_MATTER", powerUse = 180.0,
    cloakStrength = 1.0, cloakedShieldReduction = 0.50, shipLimit = 1,
})
