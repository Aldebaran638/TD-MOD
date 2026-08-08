---@diagnostic disable: undefined-global

shipComponentDefine({
    componentId = "radarSystem", slotType = "sensor",
    displayName = "雷达系统", englishName = "Radar System",
    iconPath = "MOD/gfx/ui/defense_components/sensor_1.png",
    officialComponentId = "SENSOR_1", powerUse = 5.0,
    sensorRange = 300.0, sensorInterval = 1.0, trackingAdd = 0.0,
})

shipComponentDefine({
    componentId = "graviticSensors", slotType = "sensor",
    displayName = "引力传感器", englishName = "Gravitic Sensors",
    iconPath = "MOD/gfx/ui/defense_components/sensor_2.png",
    officialComponentId = "SENSOR_2", powerUse = 10.0,
    sensorRange = 600.0, sensorInterval = 0.75, trackingAdd = 5.0,
})

shipComponentDefine({
    componentId = "subspaceSensors", slotType = "sensor",
    displayName = "亚空间传感器", englishName = "Subspace Sensors",
    iconPath = "MOD/gfx/ui/defense_components/sensor_3.png",
    officialComponentId = "SENSOR_3", powerUse = 15.0,
    sensorRange = 900.0, sensorInterval = 0.50, trackingAdd = 10.0,
})

shipComponentDefine({
    componentId = "tachyonSensors", slotType = "sensor",
    displayName = "快子传感器", englishName = "Tachyon Sensors",
    iconPath = "MOD/gfx/ui/defense_components/sensor_4.png",
    officialComponentId = "SENSOR_4", powerUse = 20.0,
    sensorRange = 1200.0, sensorInterval = 0.25, trackingAdd = 15.0,
})
