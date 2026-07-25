# CM2 武器运行架构

当前战巡武器系统按四层运行：

```text
飞船框架
  -> 武器组调度器
  -> 发射行为控制器
  -> 武器数据与客户端特效
```

## 核心接口

- `server.weaponGroupRequestFire(groupId, request)`：向一个武器组提交开火请求。
- `server.weaponGroupTick(dt)`：更新通用冷却、蓄力和控制器状态。
- `server.shipWeaponApplyConfiguration(shipType, configurationId, loadout)`：以事务方式应用框架和武器配置，并重建运行状态。

支持的行为类型为 `raycast`、`projectile`、`guidedProjectile` 和 `strikeCraft`。槽位类型只负责兼容性，不决定发射实现。

## 战巡框架

- `battleline_2x2l4m`：默认炮击框架，2H、两个实际 X 挂点、2L、4M。
- `torpedo_2x4g4m`：雷击框架，2H、两个实际 X 挂点、4G、4M。
- `siege_2x4g2m`：旧 ID，仅作为雷击框架的兼容别名。

## 添加武器

1. 在武器目录声明唯一 `weaponType`、显示名、兼容槽位和 `behaviorType`。
2. 填写 `targetingMode`、`fireProfile`、`projectileProfile`、`fxProfile` 和伤害数据。
3. 将武器加入目标飞船的 `slotWeaponPools`。
4. 复用既有行为；只有全新发射机制才注册新的行为控制器。
5. 运行 `check-weapon-system.ps1` 以及编码、Lua、XML harness。

飞船控制器不得根据具体 `weaponType` 添加分支。
