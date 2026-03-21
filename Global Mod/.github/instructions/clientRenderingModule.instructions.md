# 客户端渲染模块编写指导

> 适用范围：**仅限本工作区中的 Global Mod**。
> 参考实现：`Global Mod/client/draw_modules/hitPointFx.lua`

---

## 1. 核心结构：三件套

每个渲染模块必须包含以下三个部分，缺一不可：

| 部分 | 名称 | 说明 |
|------|------|------|
| **状态表** | `client.<fxName>State` | 模块私有状态，含 `activeEffects` 数组和事件游标 |
| **start 函数** | `local function _<fxName>Start(...)` | 内部函数，向 `activeEffects` 追加一条新特效实例 |
| **tick 函数** | `function client.<fxName>Tick(dt)` | 公开接口，每帧由 `client.clientTick` 调用 |

---

## 2. 状态表规范

```lua
client.<fxName>State = client.<fxName>State or {
    activeEffects = {},   -- 特效实例数组（支持多个并发）
    lastRenderSeq = -1,   -- 已消费的 seq，用于检测新事件
    lastShotId    = -1,   -- 已消费的 shotId（辅助校验，可选）
}
```

**要点：**
- 使用 `or {}` / `or { ... }` 保证幂等初始化（重载安全）。
- `lastRenderSeq` 是事件门控的核心，必须存在。
- `lastShotId` 在需要区分同一槽位多次发射时使用。

---

## 3. activeEffects 实例结构

每条实例至少包含：

```lua
{
    pos          = Vec(...),   -- 特效世界坐标
    normal       = Vec(...),   -- 法线方向（用于粒子散射基）
    age          = 0,          -- 已存活时间（秒），每帧 += dt
    life         = 0.6,        -- 生命期上限（秒）
    played       = false,      -- 是否已执行一次性粒子喷发
    -- 可按需追加：impactLayer, didHitShield, color, ...
}
```

**要点：**
- `played` 标志控制"只在第一帧喷发粒子"，后续帧仅推进 `age`。
- 生命期到达后 **反向迭代** 移除，避免数组下标错位。

---

## 4. tick 函数结构（强制两段）

`client.<fxName>Tick(dt)` 内部必须明确分为两个步骤：

### 步骤1：事件消费

- 获取本地玩家当前所在飞船的 Registry 快照。
- 读取 `xSlotsRender.seq`，与 `state.lastRenderSeq` 比较。
- **seq 发生变化** 时才处理事件（防止重复消费同一事件）。
- 根据 `eventType`、`didHit` 等字段决定是否调用 `_start`。
- 无论是否触发特效，都要更新 `lastRenderSeq = seq`（及 `lastShotId`）。

```lua
if seq ~= state.lastRenderSeq then
    if render.eventType == "launch_start" and render.didHit == 1 then
        _hitPointFxStart(pos, normal, render.impactLayer, render.didHitShield == 1)
    end
    state.lastRenderSeq = seq
    state.lastShotId    = shotId
end
```

**关于 timing：** `launch_start` 事件在 Registry 中会持续整个 `launchDuration`
阶段（通常 0.5 s+），客户端不会因单帧延迟而错过数据。`seq` 门控的意义是
防止同一事件被多帧重复触发，而非追赶已丢失的数据。

### 步骤2：实例更新

- 反向迭代 `activeEffects`。
- 每帧 `entry.age += dt`。
- `played == false` 时执行一次性粒子喷发，然后置 `played = true`。
- `age >= life` 时 `table.remove(effects, i)` 移除实例。

```lua
local i = #effects
while i >= 1 do
    local entry = effects[i]
    entry.age = entry.age + dt
    if not entry.played then
        _spawnParticles(entry)
        entry.played = true
    end
    if entry.age >= entry.life then
        table.remove(effects, i)
    end
    i = i - 1
end
```

---

## 5. start 函数规范

- 必须为 **局部函数**（`local function _<fxName>Start(...)`），不对外暴露。
- 只负责 **追加**一条实例到 `activeEffects`，不清除旧实例（支持并发特效）。
- 参数直接来自 Registry 快照字段，调用者（tick 步骤1）负责转换。

```lua
local function _hitPointFxStart(pos, normal, impactLayer, didHitShield)
    table.insert(client.hitPointFxState.activeEffects, {
        pos         = pos,
        normal      = normal,
        age         = 0,
        life        = 0.6,
        impactLayer = impactLayer or "none",
        played      = false,
    })
end
```

---

## 6. 辅助函数规范

以下辅助函数建议所有渲染模块统一实现：

| 函数 | 作用 |
|------|------|
| `_resolveCurrentPlayerShipBody()` | 定位本地玩家所在 stellaris ship body |
| `_tableToVec(t)` | `{x,y,z}` 表格 → Teardown `Vec` |
| `_safeNormalize(v, fallback)` | 安全归一化，零向量返回 fallback |
| `_buildPerpBasis(n)` | 由法线构造垂直基 t1/t2（用于环形散射） |

这些函数均为模块私有（`local function`），可在多个渲染模块中各自独立定义。

---

## 7. 与 client.lua 集成

在 `client.lua` 中：

1. 添加 `#include "draw_modules/<fxName>.lua"` 到 include 区。
2. 在 `client.clientTick(dt)` 的渲染更新区调用 `client.<fxName>Tick(dt)`。

```lua
-- 3) 渲染更新
client.hitPointFxTick(dt)
-- client.shieldHitFxTick(dt)  （待启用）
```

---

## 8. 触发条件速查

| `eventType` | 触发时机 | 典型渲染模块 |
|-------------|----------|--------------|
| `charging_start` | 武器开始蓄力 | `xSlotChargingFx` |
| `launch_start` | 武器发射 + 命中结算完成 | `hitPointFx`、`shieldHitFx`、`xSlotLaunchFx` |
| `idle` | 武器回到待机 | 通常无需渲染 |

`launch_start` 事件额外字段：`didHit`、`didHitShield`、`hitPoint`、`normal`、`impactLayer`。
渲染模块应在 `seq` 变化且 `eventType == "launch_start"` 时读取这些字段。