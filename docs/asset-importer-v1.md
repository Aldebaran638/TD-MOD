# Asset Importer / AssetManifest v1

## 范围

Importer v1 是只读、可重复执行的 source inspection 工具。它不修改 VOX、XML、纹理、音频、generated Lua 或最终 manifest；只把输入转换为带 provenance 的 candidate report。输入 fixture 为 `docs/candidates/asset-importer-v1.fixture.json`，工具为 `tools/cm2-asset-import/run-asset-importer-v1.ps1`，自测为同目录 `test-asset-importer-v1.ps1`。

## 输出契约

每个资源至少输出 `sourceFile/hash/license/provenance/importerVersion/readOnly`。VOX 额外输出：

- `sourceUnits=voxels`、logical `X/Y/Z` 尺寸、VOX 尺寸、voxel count、palette/material candidate；
- `sourceToVox`=`logical(x,y,z) -> vox(x,maxZ-1-z,y)` 与逆向 `voxToTeardown`；
- `metersPerVoxel`、VOX/米制 bounds、connected components、largest component、fill fraction、chunk IDs；
- `orientationCandidates`（up/forward/confidence），全部保持 `confirmed=false`，不把猜测写成事实。

XML prefab 会解析 `MOD/` 资源引用、路径边界、存在性、重复引用和 `pos/rot` transform candidate；纹理和音频以二进制 hash/字节数/provenance 进入同一 manifest。manifest core 使用稳定字段顺序并计算 deterministic `manifestHash`。

## 负例与验证顺序

自测运行两次并比较 manifest hash，同时调用 VOX 技能 validator。它通过临时 fixture 覆盖截断 chunk、XYZI 坐标越界、缺失 RGBA palette、重复 source path、XML `MOD/../` 路径穿越和缺失资源引用；所有临时文件在明确位于 `Content Mod 2/.cm2-asset-import-test-*` 后清理。正常 Hero 资产报告为 gammaStrikeCraft VOX（v150、4120 voxels、45×12×51 logical、1 connected component、8 palette colors）以及其 XML/texture/audio 依赖。

Importer 当前只产生 candidate orientation/transform，不自动确认 front/up/engine/mount，也不在 Runtime 重做 palette、压缩或优化。获得 live Teardown Shape/方向验证前，手工资产仍可照常构建；Importer 失败不得覆盖最后有效 manifest/asset。
