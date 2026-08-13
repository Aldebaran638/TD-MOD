# External Image/Text/Mesh-to-3D Pipeline v1

## 目标与流程

本步骤把外部 3D 生成服务隔离在可替换 adapter 后面。统一流程是：

    image/text/local mesh
      -> provider adapter
      -> mesh cleanup/repair/scale/axis
      -> voxelization
      -> palette/material mapping
      -> Voxtool-compatible optimization
      -> AssetManifest candidate
      -> human Editor review
      -> shared Compiler/Preview

当前实现是 offline fixture provider：它不联网、不执行任意 provider 程序、不生成真实 mesh，而是用固定输入/输出描述验证契约、质量门槛和 provenance。未来接入真实服务时只能替换 adapter，不改变 Manifest、review 和安全边界。

## Provenance 与拒绝规则

每个候选保存 inputHash、promptHash、provider/model version、license、meshHash、voxelization 参数 hash、每个阶段 hash、review status 和 finalBuildHash。缺许可证、断连组件、薄壁、palette 超限、voxel 超预算、非法轴、网络请求和 Runtime 注册均在发布前拒绝。任一失败不覆盖最后有效 AssetManifest/package。

接受候选会生成 read-only AssetManifest candidate，所有八个确定性阶段都有 input/parameter/output hash。报告随后在 disposable temp 中调用既有 Asset Build Pipeline，验证 import → validate → voxelize/convert → optimize → compile → package 的共享下游入口；不把外部候选写入 Content、Global、Runtime 或 generated。

## 回归与证据

运行：

    .\tools\cm2-ai\check-ai-external-3d-pipeline-v1.ps1
    .\tools\cm2-ai\run-ai-external-3d-pipeline-v1.ps1
    .\tools\cm2-ai\test-ai-external-3d-pipeline-v1.ps1

固定语料覆盖 image、text、local VOX 三个合法入口，以及 license、断连、薄壁、palette 和 network/Runtime 越权五个拒绝场景。结果写入 docs/candidates/ai-external-3d-pipeline-v1.result.json；重复运行要求所有阶段和下游 package hash 一致，networkCalls、publishedArtifacts、Runtime registration 和 Core 差异为 0。

真实图片/文本 provider、mesh 质量、voxelization 速度和 Teardown Preview 仍需要外部服务/实机，报告的 runtime.status=deferred 是明确限制。移除 provider 后，既有 source、AssetManifest 和手工构建流程仍可维护。

## 回退

删除候选和中间元数据，保留最后有效 AssetManifest/package；不要删除或覆盖源资产。若 provider 失败、许可证变化或质量门槛收紧，继续使用 local/manual import。

