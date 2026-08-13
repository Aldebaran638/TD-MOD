# Gate 1：ID、版本与坐标基础合同

本合同冻结后，Definition、Compiler、Editor、AI、Runtime 和 SDK 必须使用同一套身份和空间语义。机器可读的 golden 输入位于 `harness/data/contracts/id-coordinate-golden.json`；规范化工具为 `tools/normalize-cm2-contract.ps1`。

## 身份与版本

- 持久化 ID 使用 `packageId:local-id`，整个字符串区分 namespace 和局部名称。
- `packageId` 与 `local-id` 均使用 ASCII 小写；允许 `a-z`、`0-9`、`.`、`_`、`-`，首字符必须是字母或数字，长度分别不超过 64/128。
- 大小写、前后空白、Unicode 同形字不会被隐式修复；输入不符合规则即拒绝。
- alias 只用于读取旧内容并映射到唯一 canonical ID；alias 不得写回持久化数据，不得指向两个目标。
- 每种 Definition 使用独立 `schemaVersion`，格式为 `cm2.<kind>/<major>`，例如 `cm2.weapon/1`、`cm2.vehicle/1`。major 不可静默回退。

## 坐标与变换

- canonical frame：`+X = right`、`+Y = up`、`-Z = forward`；长度单位为 meter。
- 持久化附件只能写 `parentId` 和 `localTransform`；world transform 必须由 parent 链派生，不能同时持久化造成双事实来源。
- `localTransform.space` 固定为 `parent-local`；根对象的 `parentId` 为 `null`，语义等同于 root Body。
- 作者态允许 `rotationEuler`（单位必须显式为 `deg` 或 `rad`）；编译态只输出四元数 `[x,y,z,w]`。
- 编译态 position/scale/quaternion 使用 invariant culture、固定 6 位小数；`-0` 归一化为 `0`。四元数必须归一化，并通过符号规则消除 `q`/`-q` 双表示。
- 镜像是显式的 `mirror.axis`（`x`/`y`/`z`）和 `mirror.enabled`，不得用负 scale 偷渡镜像语义。

## 错误等级

| 级别 | 情况 | 默认行为 |
|---|---|---|
| `warning` | unknown-field、deprecated-field、旧 alias | 允许导入但必须写报告 |
| `error` | missing-reference、非法 ID、非法 transform、重复 canonical ID | 拒绝编译 |
| `fatal` | version-mismatch、循环 parent、无法确定 package/source | 拒绝整个 package |

## Golden cases

1. `root-body`：无 parent，单位 quaternion，验证根 Body 默认语义。
2. `shape-local`：Shape 在 root 下的局部位置与 Euler→quaternion 结果。
3. `parent-anchor`：任意 parent 下的局部 attachment，验证不存 world position。
4. `mirror-mount`：显式 X 轴镜像，验证镜像字段独立于 scale 和 quaternion。

所有机器必须对同一输入产生相同的 canonical text 与 SHA-256；验证器会拒绝未排序、非 invariant、未归一化或存在 `-0` 的输出。旧 mount 数据按 `parent=rootBody, space=parent-local` 读取，但只读 alias 不能成为新的持久化格式。

## 变更与回退

合同变更必须提升 schema major、添加 migration fixture 和新的 golden hash；不得修改既有 hash 以“修正”历史结果。回退时恢复上一个合同/fixture/tool 版本，并保留已经生成的 catalog 作为只读对照。

