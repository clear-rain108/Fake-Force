# 《Fake Forces 善假于物》—— 开发状态记录 (Dev Status)

> 关联文档：
> - `Fake_Forces_Design_v3.0.md`（剧情模式设计）
> - `Fake_Forces_Design_Puzzle.md`（解密模式设计）
> - `Fake_Forces_Lore.md`（剧情集）
> 记录当前工程实现进度、参数配置与待办事项
> 最后更新：2026-08-13（v2.0：解密模式 + 双模式架构）

---

## 一、工程信息

| 项 | 内容 |
| :--- | :--- |
| 引擎 | Godot 4.7（2D，Forward+ / D3D12） |
| 工程路径 | `D:\Fake Force\fake\Fake Force\fake-force` |
| 主场景 | `MainMenu.tscn`（主菜单，区分解密/剧情） |
| Autoload | `IllusionManager`（`scripts/IllusionManager.gd`，含 `game_mode` 双模式） |
| 素材 | `Art_Chsr_Main.png`（玩家，32×32） |

---

## 二、已实现系统

### 剧情模式（Main.tscn，阶段1+2+3）
| 系统 | 脚本 | 说明 |
| :--- | :--- | :--- |
| 幻觉管理器 | `IllusionManager.gd` | 双模式 G_TO_ACCEL：剧情 40 / 解密 10；`rotating_accel`；`get_current_effective_g` |
| 玩家 | `Player.gd` | 三分量移动；瞬时起跳（η影响）；空中微重力；洞察1秒；坠落计数；尘埃Q/Z；存档点；η光晕；**旋转圆盘模式（`rotating_mode`，待测试）** |
| 幻觉区域 | `IllusionZone.gd` + `IllusionField.gd` | G/η/k/ω 导出；CONSTANT/CYCLE/RANDOM；匀速间歇；G正弦渐变；时长抖动 |
| 幻灵/绝对方块 | `PhantomBlock.gd` | `is_phantom`；漂移范围限制 |
| 马赫尘埃 | `Dust.gd` | E收集 |
| 粒子星空 | `StarField.gd` | 跟随玩家；G=0摆动；加速度拖曳；黑洞弧线 |
| HUD | `HUD.gd` | 剧情布局 |
| 关卡生成 | `StageBuilder.gd` | 三阶段平台 |
| 记事本 | `Notebook.gd` + `NotebookTrigger.gd` | 5页剧情碎片；翻页 |
| 存档点/提示区 | `Checkpoint.gd` / `HintZone.gd` | |
| 旋转核心 | `RotatingCore.gd` | 离心ω²r；**新增 `gravity_in`（向心引力）** |
| 隐藏平台/出口 | `HiddenPlatform.gd` / `VictoryTrigger.gd` | |
| 结局演出 | `EndingSequence.gd` | 多阶段黑洞结局 |
| 开场导言 | `OpeningSequence.gd` | 8段多行 |
| 边缘红晕 | `GrimVignette.gd` | 破碎光带，0~0.8G渐变 |

### 解密模式（levels/puzzle_*.tscn，7关）
| 系统 | 脚本 | 说明 |
| :--- | :--- | :--- |
| 关卡根 | `PuzzleLevelRoot.gd` | 强制解密模式；旋转关自动绑定核心 |
| 解密HUD | `PuzzleHUD.gd` | §5.3布局（左上G/右上能量/左下尘埃/右下η+系统提示） |
| 解密胜利 | `PuzzleVictory.gd` | 白闪→哲学文字→3秒回选关页 |
| 终点 | `Goal.gd` | 金色菱形 |
| 尖刺 | `Spikes.gd` | 红色倒三角；η<0.6免疫 |
| 可撞碎墙 | `CrushableWall.gd` | η>1.5撞击粉碎 |
| 旋转挡板 | `RotatingObstacle.gd` | 弧形障碍绕核心旋转 |
| 主菜单星空 | `MenuStarField.gd` | 自转；Shift轨迹拉长 |
| 主菜单/选关 | `MainMenu.gd` / `LevelSelect.gd` | 双模式入口/7关选择 |

---

## 三、解密模式 7 关卡

| 关卡 | 谜题 | 关键元素 |
| :--- | :--- | :--- |
| 1-1 | 初识偏转 | 长滞空+大缺口(350px)，G=0.8左 |
| 1-2 | 变向偏转 | 双幻觉区（左→右上斜/右→左） |
| 1-3 | 双向往返 | U型通道，G=1.5恒右 |
| 2-1 | 幻灵垫脚 | 深渊+幻灵方块漂移+绝对方块 |
| 2-2 | 尘埃轻重 | 尖刺+可撞碎墙+4尘埃 |
| 3-1 | 离心抛射 | 旋转圆盘模型 |
| 3-2 | 科里奥利螺旋 | 旋转圆盘+3挡板 |

---

## 四、关键参数（当前值）

| 参数 | 值 | 说明 |
| :--- | :--- | :--- |
| `g_to_accel` | 剧情 40 / 解密 10 | 双模式换算 |
| 解密 `speed` | 35 | 低推力→幻觉力占推力23~43%（明显） |
| 解密 `jump_velocity/gravity` | 150 / 120 | 滞空2.5s，幻觉偏移明显 |
| 洞察 | 1秒消耗，3秒恢复 | |
| 尘埃步长（解密2-2） | 0.7 | Z→0.3飘尖刺；Q→1.7撞墙 |
| 旋转核心 | ω=1.5, gravity_in=560 | 平衡半径≈249 |

---

## 五、已知问题 / 待办

- [x] 双模式架构（主菜单/选关页）
- [x] 解密 7 关搭建 + 新元素（尖刺/墙/挡板）
- [x] 解密参数校准（speed 35，幻觉明显）
- [ ] **旋转圆盘模型【待测试/更改】**：3-1/3-2 当前手感未经用户验收，可能需重构
- [ ] 1-2 斜向幻觉效果待用户验证
- [ ] 1-3 平台辅助跳跃细化
- [ ] 各关难度/数值逐关校验
- [ ] 解密模式音效
- [ ] 剧情模式：场景拆分（阶段3独立 Stage3.tscn）、音效、尘埃η谜题、收尾打磨

---

> 文档版本：v2.0（开发状态记录）
> 说明：每次开发迭代后更新本文件。


