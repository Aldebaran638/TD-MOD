# Compiler MVP 四条纵切 candidate

`ownership-map.json` 固定四条旁路纵切的 source、legacy 对照路径和 ownership。`tools/cm2-slices/build-vertical-slices.ps1` 将它们编译到本目录的 candidate catalog；生成文件带 `DO NOT EDIT` header，不能手工覆盖 `Content Mod 2` 的 legacy catalog。

| 切片 | 覆盖语义 | Legacy 对照 |
|---|---|---|
| `ray-beam` | ray weapon → beam effect | X-slot `arcEmitter` |
| `logical-projectile-impact` | projectile weapon → logical projectile → impact effect | X-slot `gigaCannon` |
| `guided-missile` | guided weapon → guided projectile → trail/impact effect | M-slot `swarmerMissile` |
| `tachyon-charge-beam-impact` | charged weapon → charge/beam/impact effects | X-slot `tachyonLance` |

Candidate catalog 只有在四条纵切的 normalized source 与 legacy semantic snapshot 对照、Presentation/Effect runtime dual-run 和 Gate 1 评审通过后，才允许进入 generated runtime ownership；当前仍是 `generated-candidate-only`。

