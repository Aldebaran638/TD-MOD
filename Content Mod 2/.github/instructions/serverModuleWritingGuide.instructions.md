# 战列巡洋舰服务端模块编写指南

模块按“拥有者”和“核心职责”归档，不按调用者归档。

## 归类规则

- 飞船初始化：`ship/battlecruiser/server/bootstrap/`
- 飞船级武器编排：`ship/battlecruiser/server/control/`
- 飞船移动、阻尼与姿态：`ship/battlecruiser/server/movement/`
- 跨武器通用设施：`weapon/server/common/`
- M/G 槽共享制导运行时：`weapon/server/guided/`
- 单一武器状态与行为：`weapon/server/slots/<slot>/<weapon>/`

例如，快子光矛属于：

```text
weapon/server/slots/x/tachyon_lance/
```

X 槽通用锁定状态可以放在 `slots/x/`，但快子光矛专属蓄力或伤害不得命名成 X 槽通用模块。

## 编写约束

1. 一个文件只承担一个可清楚命名的职责。
2. 同时涉及多个领域时拆成多个模块，由组合入口调度。
3. 当前飞船模块优先使用 `server.shipBody`。
4. Registry 状态通过统一访问层读写。
5. 新文件使用小写 `snake_case`。
6. 新增模块后必须加入入口 include 闭包，并通过 Lua/API 检查。
