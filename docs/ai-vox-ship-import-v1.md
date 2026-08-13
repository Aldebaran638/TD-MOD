# Existing-VOX Ship Import Assistant v1

## 目标

这一步先解决已有 VOX 的可测量导入，不承诺“图片一键生成可玩飞船”。Assistant 读取 v150 VOX 的 SIZE/XYZI/RGBA，按 Teardown 约定转换逻辑轴，并输出 engine、camera、mount、symmetry、complexity 与 performance-class 建议。

采用的坐标契约是：

    logical X = left/right
    logical Y = down/up
    logical Z = rear/front
    voxX = logicalX
    voxY = logicalSizeZ - 1 - logicalZ
    voxZ = logicalY
    VOX SIZE = (logicalSizeX, logicalSizeZ, logicalSizeY)

模型方向不会由 PCA 或最长轴自动决定。报告同时给出 logical+Z 和 logical-Z 两个 forward 候选，up 固定为 logical+Y；engine 位置给出两个 rear-face 候选，需在渲染 Shape bounds 上复核。scale 只提供 0.05、0.1、0.2 m/voxel 候选，不能用近似值替代实测。

## 安全边界

Assistant 只读 asset、生成 metadata/anchor candidate 并运行 VOX validator。默认拒绝 Runtime registration、Core/generated/Lua/network、voxel rewrite 和 auto-build。每个模型记录 asset hash、model index、VOX version、parser version、scale candidates、confidence、review status 和 finalBuildHash；低 confidence 阻断构建。

## 回归与证据

运行：

    .\tools\cm2-ai\check-ai-vox-ship-import-v1.ps1
    .\tools\cm2-ai\run-ai-vox-ship-import-v1.ps1
    .\tools\cm2-ai\test-ai-vox-ship-import-v1.ps1

固定语料使用三个真实 v150 资产：gammaStrikeCraftTest、escort_1、WUJINHAO，共七个模型记录。每个资产先运行 build-teardown-vox-models 技能提供的 validate-vox.ps1，再做二进制/坐标/对称性分析。回归要求至少三种主轴排序、两种对称类别、所有 recommendation 进入人工复核、Core 差异/资产写入/Runtime registration 为 0，重复 determinismHash 相同。结果写入 docs/candidates/ai-vox-ship-import-v1.result.json。

本步骤不修改 VOX，也不假装完成实机方向、比例、Shape bounds、附件跟随或截图验证；这些需要 Teardown.exe。加载模型后应按“先无效果确认轮廓和朝向，再调 XML，再用 GetShapeBounds/本地变换绑定附件”的顺序复核。

## 回退

删除建议报告并保留原始 VOX/source；不做二进制重写，不注册 Runtime 舰船。人工确认每个轴、scale、engine/camera/mount 后，才允许进入下一步 Source Definition/Compiler。

