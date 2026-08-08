---@diagnostic disable: undefined-global

shipComponentDefine({
    componentId = "chemicalThrusters", slotType = "thruster",
    displayName = "化学推进器", englishName = "Chemical Thrusters",
    iconPath = "MOD/gfx/ui/defense_components/thruster_1.png",
    officialComponentId = "BATTLESHIP_SHIP_THRUSTER_1", powerUse = 80.0,
})

shipComponentDefine({
    componentId = "ionThrusters", slotType = "thruster",
    displayName = "离子推进器", englishName = "Ion Thrusters",
    iconPath = "MOD/gfx/ui/defense_components/thruster_2.png",
    officialComponentId = "BATTLESHIP_SHIP_THRUSTER_2", powerUse = 120.0,
    speedMultiplier = 0.25, turnResponseMultiplier = 0.25, turnForceMultiplier = 0.25,
})

shipComponentDefine({
    componentId = "plasmaThrusters", slotType = "thruster",
    displayName = "等离子推进器", englishName = "Plasma Thrusters",
    iconPath = "MOD/gfx/ui/defense_components/thruster_3.png",
    officialComponentId = "BATTLESHIP_SHIP_THRUSTER_3", powerUse = 160.0,
    speedMultiplier = 0.50, turnResponseMultiplier = 0.50, turnForceMultiplier = 0.50,
})

shipComponentDefine({
    componentId = "impulseThrusters", slotType = "thruster",
    displayName = "脉冲推进器", englishName = "Impulse Thrusters",
    iconPath = "MOD/gfx/ui/defense_components/thruster_4.png",
    officialComponentId = "BATTLESHIP_SHIP_THRUSTER_4", powerUse = 200.0,
    speedMultiplier = 0.75, turnResponseMultiplier = 0.75, turnForceMultiplier = 0.75,
})

shipComponentDefine({
    componentId = "darkMatterThrusters", slotType = "thruster",
    displayName = "暗物质推进器", englishName = "Dark Matter Thrusters",
    iconPath = "MOD/gfx/ui/defense_components/thruster_5.png",
    officialComponentId = "BATTLESHIP_SHIP_THRUSTER_5", powerUse = 240.0,
    speedMultiplier = 1.25, turnResponseMultiplier = 1.25, turnForceMultiplier = 1.25,
})
