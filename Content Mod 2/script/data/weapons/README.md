# CM2 武器定义标准

本目录的运行时武器定义分为三类。所有字段都直接写在 `weaponDefine...({...})` 的定义表中；不要用 `family` 选择运行时行为。

## 蓄力激光武器

使用 `weaponDefineRay`，并且必须包含：

```lua
behaviorType = "raycast"
controllerType = "chargedRay"
chargeDuration = 0.50
launchDuration = 0.20
chargeFxProfile = "..."
fxProfile = "..."
muzzleFxProfile = "..."
impactFxProfile = "..."
soundProfileId = "..."
```

`chargeFxProfile` 只负责蓄力表现，`fxProfile` 只负责释放后的射线，`muzzleFxProfile` 负责枪口，`impactFxProfile` 负责命中，`soundProfileId` 负责音效。蓄力生命周期由 `controllerType` 控制，攻击行为由 `behaviorType` 控制。

## 非蓄力激光武器

使用 `weaponDefineRay`，并且必须包含：

```lua
behaviorType = "raycast"
fxProfile = "..."
muzzleFxProfile = "..." -- 没有专用枪口时使用 "none"
impactFxProfile = "..." -- 没有专用命中时使用 "none"
soundProfileId = "..." -- 没有专用声音时使用 "none"
```

不得包含 `controllerType = "chargedRay"`、`chargeFxProfile` 或蓄力时长字段。

## 弹道武器

经典弹道武器使用 `weaponDefineProjectile`，统一包含：

```lua
behaviorType = "projectile"
fxProfile = "..."              -- 弹丸飞行主体和尾迹算法
muzzleFxProfile = "..."        -- 发射口效果
impactFxProfile = "..."        -- 命中效果
projectileFxVariant = "..."    -- 同一飞行算法的外观变体
soundProfileId = "..."         -- 发射/命中音效
projectileSpeed = 150.0
projectileRadius = 0.35
```

战斗数值字段为 `damageMin`、`damageMax`、`shieldFix`、`armorFix`、`bodyFix`、`powerUse`、`cooldown`、`maxRange`。连续射击武器还应声明 `heatPerShot`、`heatDissipationPerSecond`、`overheatThreshold` 和 `recoverThreshold`。

`projectileSpeed` 控制服务器和客户端的飞行速度；`projectileRadius` 用于护盾/弹丸碰撞的粗略半径，不代表图标或模型尺寸。

`fxProfile` 只决定飞行表现，`projectileFxVariant` 只决定飞行外观变体，`muzzleFxProfile` 只决定枪口，`impactFxProfile` 只决定命中。不要使用旧的嵌套 `projectileProfile`、`projectileGravityScale` 或 `explosionStrength`，除非对应运行时先明确接入。

所有武器都应声明 `slotTypes`、`mountProfile`、`salvoProfile`、`aimControlMode`、`aimLimitDeg`、`aimPitchOffsetDeg` 和 `officialComponentId`。`stellaris_generated_4_4_6.lua` 的原始清单可以保留 `family` 作为导入来源分类，但加载时必须先转换为上述显式字段；`family` 不得复制到 `weaponData`，也不得被客户端或服务端运行时分派读取。
