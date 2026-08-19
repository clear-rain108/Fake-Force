# 《Fake Forces 善假于物》—— 开发状态记录 (Dev Status)

> 关联文档：
> - `Fake_Forces_Design_v3.0.md`（剧情模式设计）
> - `Fake_Forces_Design_Puzzle.md`（解密模式设计）
> - `Fake_Forces_Lore.md`（剧情集）
> 记录当前工程实现进度、参数配置与待办事项
> 最后更新：2026-08-19（v0.2 音频修复：关卡音乐循环 / 结局背景音乐文件名大小写）
> - [x] **音频修复（v0.2）**：①**剧情（及全部）关卡音乐不循环**——根因 `LOOP1sp.test.ogg.import` 导入参数 `loop` 被回退为 `false`；已恢复为 `true`，并在 `BackgroundController._ready` 运行时兜底强制 `Music.stream.loop=true`（覆盖所有剧情/解密关卡，导出包同样生效）。②**结局背景音乐未播放**——根因 `EndingSequence.gd` 按 `res://The thinking of star.ogg`（大写）加载，而磁盘文件为 `the thinking of star.ogg`（小写，Windows 大小写不敏感导致静默漂移），源码运行仅告警、导出 PCK 大小写敏感直接加载失败；已把磁盘文件与 `.import` 源路径统一为大写 `The thinking of star.ogg` 并重新导入。`tests/EndingProbe.tscn` 验证无 Case mismatch 警告、结局曲播放/时间轴对齐全 PASS；`tests/AudioDurProbe.tscn` 验证三曲时长与循环状态（结局/菜单曲保持不循环、关卡曲运行时 `loop=true`）
> - [x] **结局动画重写**（`EndingSequence.gd`）：删除老人面孔与"Demo 结束"；结局文本改为**逐段淡入淡出**（如开场动画）——引号段=老人遗言（暖色）、纯文本段=旁白（苍蓝），共 12 段；黑洞本体重绘；Esc 退出保留。`tests/EndingProbe.tscn` 验证进入文字阶段无错误
> - [x] **结局演出细化（v3.5）**：黑洞仅在**老人遗言期间**显示，遗言结束（第4段播完）后**黑洞消失**、**黑屏 1s** 再开始播放旁白；结局**不播放音乐**（`start_ending` 静音 Music 总线）（v3.7 起改为播放结局背景音乐 "The thinking of star"，此条被取代）；`tests/EndingProbe.tscn` 验证文字阶段 + 音乐静音全 PASS
> - [x] **通关致谢 + 自动退出（v3.6）**：旁白结束后显示致谢字幕"**感谢游玩《Fake Forces 善假于物》**"（停留约 4.5s），随后**自动结束游戏**（`EndingSequence` 在 `_process` 中 `get_tree().quit()`，无需按键）；`tests/EndingProbe.tscn` 全流程验证（文字阶段 / 音乐静音 / 感谢字幕进入 / 自动退出）全 PASS
> - [x] **洞察箭头单位化（v3.8）**：普通参考系 **1G**、旋转参考系 **10G** 各自作为单位化长度，箭头长 = **3 玩家身位（96px）**（`Player._arrow_scale()`：普通 9.6 / 旋转 0.96 px/(px·s⁻²)；各参考系内仍同比例、合力=运动可验证）；箭头**更细**（线宽 4→2px、头部 12→8px≈半个身位）；**系统阻力调小**——阻尼**物理 ×0.6**（`IllusionManager.SYSTEM_RESIST_SCALE`）+ 空中重力**显示 ×0.6**（`Player.SYSTEM_ARROW_SCALE`，跳跃物理不变）→ 横向绿箭头变短（旋转系绿箭头=-ω²R 为物理量不受影响）；`tests/ArrowUnitProbe.tscn` 验证（1G/10G→96px、物理阻尼0.3、重力显示×0.6、线宽）全 PASS
> - [x] **结局背景音乐 + 时间轴对齐（v3.7）**：结局背景音乐改为 **"The thinking of star.ogg"**（`Music` 总线、音量 -6dB；`start_ending` 时停止关卡背景音乐 `background.tscn/Music` 再播放结局曲）；**演出时间按音乐时长等比缩放**——设计总长 54.2s × k（k=音乐长/54.2，结局曲 110.55s→k≈2.039），白闪/滑入/每段文字/黑屏/致谢全部同步放大，**演出结束时刻 = 音乐结束时刻**（110.553337s，逐项核对相等）；致谢字幕在旁白播完（~101.4s）后进入；`tests/EndingProbe.tscn` 验证文字阶段 / 背景音乐播放（关卡曲停止）/ 时间轴对齐 / 感谢字幕 / 自动退出全 PASS
> - [x] **剧情集同步**（`Fake_Forces_Lore.md` v1.6）：结局文本全量更新（老人遗言+旁白）、人物条目/三幕结构去掉"老人面孔"、补充强制休眠死亡演出全台词
> - [x] **探针清理**：删除不涉及真实关卡的合成探针（`RotCamTest`、`StoryDeathProbe`——程序化搭建玩家/核心），保留全部加载真实关卡（Main/Q5/T4/Stage3）的探针
> - [x] **旋转环廊平台重构**：RingGround(顶625) 与 CorePlatform(圆盘,顶525) 拉开 100px 间距、阶梯逐级 +90（Step1 顶435→Step2 345→Step3 255→Transition 165），修复"玩家传送后被卡在两平台之间"；中控室跃迁传送点改到 (7900,605)（安全网正上方）
> - [x] **旋转参考系行为修复**：①平台透明——`_collect_polys` 改为收集 StaticBody2D 下**所有 Polygon2D**（此前只认名为 `Poly` 的子节点，StageBuilder 生成的平台永不透明）；②玩家被核心掩盖——`RotatingCore.z_index=-1`（玩家绘制在核心之上）；③切入前无推力（环廊重构后圆盘处无交叠卡顿，`tests/RotFadeProbe.tscn` 验证漂移 4px、切入后平台 alpha≈0）
> - [x] **移除剧情关卡 HintZone 关卡提示**（HintZoneMaze/Stage2/Ring 已删），仅保留左上 HUD 系统消息（进入/脱离参考系、机关、尘埃等）
> - [x] **阶段3黑洞本体**：新增 `BlackHole.gd`（暗黑视界+吸积盘亮环+引力透镜光弧+绕转粒子），替换 Stage3 的 RotatingCore（保留 omega/influence_radius 与 "RotatingCore" 组绑定，旋转物理无缝）；**准备阶段3重构与结局动画联动**
> - [x] **打磨①：开场动画播放关卡音乐**——开场暂停游戏树会把 `background.tscn` 的 `Music` 与 `AudioManager` 常驻 Drone 一起停掉；已把二者设为 `process_mode=ALWAYS`（开场暂停期间音乐/环境音继续）
> - [x] **打磨②：走廊房间加墙 + 丰富内饰**——走廊加整条天花板 `RoomCeiling`(x0~3200) 与左端墙 `RoomWallLeft`(x=0)，隔墙视觉延伸至天花板（碰撞保持门洞不变，不影响通行）；每个房间新增衣柜/顶灯（共10个装饰节点）
> - [x] **打磨③：初始位置不易摔死**——出生点 (0,650)→(120,650)（不再贴走廊左缘），配合左端墙，开场后玩家被 G=0.6 推力推向左端时被挡住不会坠出走廊。`tests/SpawnSafetyProbe.tscn` 验证：玩家存活、最小 x≈87（被墙挡在走廊内）
> - [x] **Bug修复①：开场动画期间玩家死亡触发死亡演出**——`OpeningSequence` 开场即暂停游戏树（玩家静止不被幻觉推力推落），播放完/空格跳过/被释放时经 `_exit_tree` 兜底自动恢复（防卡暂停）
> - [x] **Bug修复②：死亡演出结束游戏被强制退出**——根因：死亡演出 `change_scene` 销毁场景时，房间5尘埃(Dust1)的 `tree_exiting` 在销毁中触发 `Stage1Controller._on_room5_dust_collected`，此时 `get_tree()` 已失效 → 崩溃；已改为 `is_inside_tree()` 守卫忽略销毁中的回调。`tests/DeathFlowProbe.tscn` 验证：死亡演出完整播放 → 无错误切回 MainMenu
> - [x] **阶段1重构（走廊过道→迷宫→中控室）**：`StageBuilder` 阶段1平台改为连续走廊地板（x0~3200，5间房间由薄墙+门洞分隔，装饰床/桌/舷窗）；房间5尘埃 → 记事本第1页 + 迷宫闸门(MazeEntranceGate)打开 + 强推力(PushToMaze G=2.0)启用；迷宫保留幻灵/绝对方块并加第2层(MazeMid)与最高层(MazeTop)，终点 MazeExitSwitch → 记事本第2页 + 中控室舱门(ControlRoomDoor)打开；中控室(5200~5520)内 LaunchButton（进入显示"按E跃迁"）→ 黑屏淡出 → 背景切太空 + 玩家传送旋转环廊起点。新建 `Stage1Controller.gd`（叙事触发，不改动任何核心脚本）；`Corr1/Corr2` 平台与 `Zone2A/2B` 让位于中控室。自动验证 `tests/MainFlowProbe.tscn` 全 PASS。
> - [x] **幻觉强度边框按参考系校准**：`Player.linear_g_visual_ref`（普通=1.5G 满边框）与 `rot_g_visual_ref`（旋转=20G 满边框），Player 每帧写入 `IllusionManager.vignette_g_ref`；GrimVignette 与剧情/解密 HUD 的 G 标签颜色同步按此参考（普通 1.5G 已很大 / 旋转十余 G 仅普通）
> - [x] **幻觉强度边框更细碎**：GrimVignette 片段数 22~62、更薄（8~32px）、带随机留白的短片段
> - [x] **剧情模式坠落死亡演出**（`scripts/DeathSequence.gd`）：坠落过多不再提示"按 R 重开"，改为渐入黑屏 → 逐段文字（检测到非正常情绪波动…/睡意…/木星…/重启流程 5,4,3…/0.）→ 回开始页 MainMenu；空格可跳过；自动验证 `tests/StoryDeathProbe.tscn`（ref 切换 1.5↔20 与 DeathSequence 挂载全 PASS）
> - [x] **旋转参考系"脚指向核心"**（`rot_feet_to_core=true`，T4/Q4/Q5/Q6/Main/Stage3 全部旋转关卡）：玩家旋转 = 玩家→核心方向 −π/2、摄像机全局取同值（局部≈0），核心恒屏显正下方、精灵头朝上、世界旋转；跟踪速率 20（平滑滞后 ~2°）；自动验证 `tests/FeetCoreProbe.tscn`（真实 Q5：核心 X 偏移 <10px@R200、精灵屏显旋转=0、无 2× 叠加）
> - [x] **旋转系惯性力缩放**（`Player.inertia_scale=0.5`）：离心+科里奥利写入幻觉显示系统（G/红箭/幻灵/星空）减半，玩家实际受力与轨道不变

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

### 剧情模式（阶段1+2 = `Main.tscn`，阶段3 = `scenes/Stage3.tscn`，黑屏淡入淡出过渡）
| 系统 | 脚本 | 说明 |
| :--- | :--- | :--- |
| 幻觉管理器 | `IllusionManager.gd` | 双模式 G_TO_ACCEL：统一 10；`vignette_g_ref`（幻觉强度边框参考，Player 按参考系切换 1.5/20）；`get_current_effective_g`；**区域计数/记事本解锁持久化** |
| 玩家 | `Player.gd` | 三分量移动；瞬时起跳（η影响）；空中微重力；洞察最长5s+尘埃加成；坠落计数（**剧情坠落过多→DeathSequence 强制休眠演出**）；尘埃Q/Z（旋转输入推力÷η）；存档点；η光晕；旋转圆盘模式（**脚指向核心 rot_feet_to_core**）；**惯性力缩放 inertia_scale**；旋转同步计数；重生/重试重置旋转状态 |
| 幻觉区域 | `IllusionZone.gd` + `IllusionField.gd` | G/η/k/ω 导出；CONSTANT/CYCLE/RANDOM；匀速间歇；G正弦渐变；时长抖动；**进入记录（note_zone）** |
| 幻灵/绝对方块 | `PhantomBlock.gd` | `is_phantom`；漂移范围限制；`bounce` 反弹；`counts_as_occupant` |
| 马赫尘埃 | `Dust.gd` | E收集（累计数供记事本判定） |
| 粒子星空 | `StarField.gd` | 跟随玩家；G=0摆动；加速度拖曳；黑洞弧线 |
| HUD | `HUD.gd` | 剧情布局 + `show_system_message` |
| 关卡生成 | `StageBuilder.gd` | 阶段1+2 平台（偏转回廊→机关/迷宫→多场走廊→旋转环廊→黑洞舱门） |
| 记事本 | `Notebook.gd` + `NotebookTrigger.gd` | 5页剧情碎片；**事件驱动解锁**（尘埃/机关/迷宫出口/多场+旋转同步/衔接处）；跨场景持久 |
| 机关 | `Switch.gd`（新） | 触碰解锁记事本页 + 开启舱门 |
| 阶段过渡 | `StageFade.gd`（新，Autoload）+ `StageTransition.gd`（新） | 黑屏淡入淡出跨场景切换 |
| 根节点 | `StoryRoot.gd`（新）/ `Stage3Root.gd`（新） | 阶段1+2 飞船内部背景 / 阶段3 宇宙背景 + 核心绑定 |
| 存档点/提示区 | `Checkpoint.gd` / `HintZone.gd` | |
| 旋转核心 | `RotatingCore.gd` | 视觉自转 + 圆盘绘制；虚假力由 `Player._rotating_physics` 计算写入幻觉系统（阶段2 环廊 + 阶段3 无重环带） |
| 隐藏平台/出口 | `HiddenPlatform.gd` / `VictoryTrigger.gd` | 阶段3 隐藏路径 + 黑洞视界出口 |
| 结局演出 | `EndingSequence.gd` | 多阶段黑洞结局（阶段3 内） |
| 开场导言 | `OpeningSequence.gd` | 9段多行（阶段1 开场） |
| 边缘红晕 | `GrimVignette.gd` | 细碎破碎光带；0~`vignette_g_ref` 渐变（普通参考系 1.5G 满 / 旋转参考系 20G 满） |
| 强制休眠演出 | `DeathSequence.gd` | 剧情坠落过多 → 渐入黑屏 + 逐段文字 → 回开始页（空格跳过） |

### 解密模式（levels/T*.tscn / Q*.tscn，10关：教学4 + 主线6）
| 系统 | 脚本 | 说明 |
| :--- | :--- | :--- |
| 关卡根 | `PuzzleLevelRoot.gd` | 强制解密模式；旋转关自动绑定核心；**自动挂载暂停菜单** |
| 解密HUD | `PuzzleHUD.gd` | §5.3布局（左上G/右上能量/左下尘埃/右下η+系统提示） |
| 解密胜利 | `PuzzleVictory.gd` | 白闪→哲学文字→3秒回对应选关页（`return_scene`） |
| **暂停菜单** | `PauseMenu.gd` | Esc 开关；继续/返回主菜单/退出游戏 |
| 终点 | `Goal.gd` | 金色菱形 |
| 尖刺 | `Spikes.gd` | 红色倒三角；η<0.6免疫 |
| 可撞碎墙 | `CrushableWall.gd` | η>1.5撞击粉碎（距离检测+发光屏障视觉） |
| 旋转挡板 | `RotatingObstacle.gd` | 弧形障碍绕核心旋转 |
| 主菜单背景 | `menu_background.tscn` | 开始页太空星云背景 |
| 主菜单/选关 | `MainMenu.gd` / `LevelSelect.gd` / `TeachingSelect.gd` | 教学入口 + 双模式选关 |

---

## 三、解密模式 10 关卡（教学 T + 主线 Q）

### 教学关卡（主菜单 → 教学关卡）
| 关卡 | 谜题 | 关键元素 |
| :--- | :--- | :--- |
| T1 | 初识偏转 | 平台+缺口(250px)，G=0.8**向左** |
| T2 | 幻灵垫脚 | 深渊+幻灵方块**被吹向左**+绝对方块参照（带提示） |
| T3 | 尘埃轻重 | 尖刺+可撞碎墙+4尘埃（带操作提示） |
| T4 | 旋转参考系 | 双平台深渊+悬浮圆盘（ω=0.6）；跳入→Shift切换→同步→A/D/W/S→**切向加速甩出**；**旋转系内平台隐身**；提示由 `T4Guide.gd` 状态驱动（进入/脱离时机精确） |

### 主线关卡（解密模式）
| 关卡 | 谜题 | 关键元素 |
| :--- | :--- | :--- |
| Q1 | 变向偏转 | **风向标之塔·逐层对抗**：5层爬升，方向逐层变化（顺/逆风交替），部分楼层CYCLE、顶层RANDOM；红色风向标箭头指示 |
| Q2 | 双向往返 | **蛇形回流·水平往返**：底层去程顺风→中层回程逆风（缺口+下方尖刺）→顶层出口，G=1.5恒右 |
| Q3 | 幻灵航路 | **综合关**：幻灵浮桥（双方块接力+反弹摆动）+ 尘埃天平（轻飘刺/重撞墙）+ 相位走廊（CYCLE借漂移方块跳越）；`PhantomBlock.bounce/counts_as_occupant` 新增 |
| Q4 | 参考系登高 | 底层横向→上层旋转圆盘→**甩出到核心正上方出口平台**（A/D切向加速甩出，出口旋转系内隐身） |
| Q5 | 离心抛射 | **巨大实体圆盘**（core 250），随盘转+绕盘移动 |
| Q6 | 科里奥利螺旋 | 旋转圆盘+3挡板，需甩出到达外平台 |

---

## 四、关键参数（当前值）

| 参数 | 值 | 说明 |
| :--- | :--- | :--- |
| `g_to_accel` | 统一 10 | 剧情/解密 G→加速度 换算一致（操作手感统一） |
| 玩家参数 | 统一 speed 60 / 跳跃300/200 / max140（教学 T2=55、T3=45 特例） | 剧情/解密操作手感完全统一 |
| 洞察 | 最长 5s + 每枚尘埃 +1s；1秒满格恢复；切换洞察无限时 | |
| 尘埃步长 | 0.7 | Z→0.3飘尖刺；Q→1.7撞墙 |
| 旋转核心 | ω=0.8 | 圆盘线速度 ωr=160 |
| 旋转输入 | radial/tang = 60 | A/D切向、W/S径向 |

---

## 五、已知问题 / 待办

- [x] 双模式架构（主菜单/选关页）+ **教学/主线 TQ 分类**
- [x] 解密 8 关搭建 + 新元素（尖刺/墙/挡板/暂停菜单）
- [x] 解密参数校准（speed 60/55，跳跃 300/200）
- [x] 旋转参考系核心物理（向心力圆周运动、幻觉场写入、开局同步）
- [x] 幻觉方向语义修复（field_directions=参考系加速方向，幻觉力=-方向）
- [x] 蓝色墙/返回场景修复
- [x] 选关页文件名修复（puzzle_* → T*/Q*）+ T3 通关返回教学选关页
- [x] 旋转参考系切换逻辑修复（`_last_insight_in_rot` 只在按下时记录；重生/重试重置旋转状态）
- [x] **新增 T4 旋转参考系教学关 + 旋转系常规平台隐身机制（全旋转关卡生效）**
- [x] T4 提示改状态驱动（T4Guide：进入/脱离时机精确）+ 系统提示文案区分（进入="建议切换" / 脱离="已自动恢复原参考系"）
- [x] 洞察箭头图例全局化（`ArrowLegend.gd` 由 PuzzleHUD/HUD 自动挂载，横向/旋转/切换自适应）+ 旋转系箭头语义统一（蓝=输入、红=惯性力）
- [x] Q3 出口重设计（圆盘上 → 核心正上方，需切向加速甩出到达）
- [x] **死代码清理**：删除 `LevelGen.gd`（沙盒生成器，无引用）、`LOOP1sp.test.ogg`（测试音频，无引用）；移除未用变量 `Player.safe_ring_strength` / `RotatingCore.gravity_in`；移除无调用 getter `get_current_g/get_current_omega/get_current_eta`
- [x] **动态星空背景系统**（CanvasLayer -1）：星云+星星着色器（洞察定格 / G 变暗）、GPUParticles2D 尘埃（流向随虚假力×0.5 旋转）、扭曲层（ω→引力透镜 0~0.08，默认隐藏）；`IllusionManager.is_insight_mode` 由 Player 每帧同步
- [x] **背景音乐接入**：恢复 `LOOP1sp.test.ogg`，随背景场景自动播放（全部可玩关卡）
- [x] **开始页音乐**：`MainMenu` 播放 `Out of the spaxe.ogg`（每次进入主菜单重新播放，不循环）
- [x] **关卡音乐循环修复**：`LOOP1sp.test.ogg` 导入 loop=false → true
- [x] **音量控制**：暂停菜单内"音乐/音效"双滑块（Music / SFX+Ambient+Voice 总线），持久化 `user://settings.cfg`
- [x] **程序化音效系统**：`AudioManager`（Autoload）——常驻 Ambient Drone（双 Generator 流，G/洞察实时联动）、移动风声（粉红噪声带通）、洞察扫频、尘埃/记事本/区域过渡/黑洞序列音效；`audio_buses.tres`（Master/Music/Ambient+LPF+Reverb/SFX/Voice）
- [x] **开始页/选关页背景**：开始页太空星云背景（`menu_background.tscn`，替换旧白点星空）；选关页 `select_background.tscn` 太空默认 + 悬停平滑交叉淡化——教学页固定飞船内部（`ship_interior.gdshader`）、解密页 Q1/Q2 飞船内部 / Q3~Q5 太空
- [x] **旋转参考系玩家表现**：脚指向核心 + 视野 0.8（zoom）+ 摄像机锁定核心固定屏幕上方（相对位置不变）+ 脱离自动回正（`_update_rot_visual`）
- [x] **旋转参考系按键/箭头修复**：W/S 径向映射反转（W=向心↑、S=离心↓，与屏幕一致）；A=逆时针 / D=顺时针；`_draw` 箭头 `.rotated(-rotation)` 修正被玩家旋转污染的受力箭头；新增 `RotKeyHint`（旋转系内持续显示 WASD 方向）；ArrowLegend 注释更新（A/D 逆/顺时针、删"系统在推你"）
- [x] **关卡内背景与选关按钮一致**：`background.tscn` 增加飞船内部层（`ship_interior.gdshader`），`BackgroundController.set_theme` 平滑淡化；`PuzzleLevelRoot.bg_theme` 配置——T1~T4/Q1/Q2=飞船内部、Q3~Q5=太空（与选关页完全一致）；飞船背景复用尘埃粒子（舱内漂浮微粒）+ 游戏配色
- [x] **飞船背景重写（金属科幻风）**：去掉格栅/格子，改为拉丝金属 + 分块面板（接缝+四角铆钉）+ 斜切金属板高光 + 发光灯条 + 指示灯 + 扫描光 + 弯曲管线
- [x] **全局字体 fusion-pixel**：`project.godot [gui] theme/custom_font`；关闭像素字体抗锯齿（antialiasing=0）；6 个脚本 `_draw` 文字改用 fusion-pixel；全部 Label/文字字号规整为像素友好整数（14/15→16、18→20、22/26/34→24/32 等）
- [x] **剧情模式交互完善**：开幕剧情按空格跳过（文字下方提示）；记事本阅读时游戏暂停（记事本 `PROCESS_MODE_ALWAYS` 仍可翻页/关闭），**移除 Esc 退出阅读**（仅 F 关闭，提示改为"← → 翻页 ｜ F 关闭"），暂停菜单在阅读中忽略 Esc；`R` 键在剧情模式改为**恢复最近存档点**（`reset_level`；解密模式仍为重开当前关卡），HUD 失败提示改为"按 R 恢复存档点"；剧情模式新增 **Esc 暂停菜单**（`StoryRoot`/`Stage3Root` 挂载 `PauseMenu`，含继续/重开游戏/返回主菜单/退出）
- [x] **洞察/操作/体验优化**：洞察 5s+尘埃加成/1s 恢复/切换无限时；`R` 键在解密改为重开（重载当前场景）+ 暂停菜单新增"重开游戏"；教学提示改为持续显示（`HintZone.persistent` + HUD 持久提示，临时提示后自动恢复）；开始页标题"假"红/"物"蓝（RichTextLabel BBCode）；剧情开场按空格跳过并补台词"去哪？或许，唯一的线索，只会在那儿。"（倒数第二句）；`PhantomBlock.activation_distance`（玩家未到附近时幻灵方块不提前漂移）；代码优化——6 处 `_draw` 字体缓存 + StarField/BackgroundController 节点引用缓存
- [x] **剧情模式重构（三幕分场景）**：阶段1+2 = `Main.tscn`（飞船内部背景）——偏转回廊（缺口教学+第1枚尘埃）→ 机关舱门（`Switch.gd`，第2页）→ 迷宫（幻灵方块垫脚+绝对方块参照，出口第3页）→ 多场走廊（4区：右/左/CYCLE/RANDOM）→ 旋转环廊（同步后第4页）→ 黑洞舱门（第5页+黑屏淡出）；阶段3 = `Stage3.tscn`（宇宙背景·全局无重力·尘埃调η·隐藏路径·结局）；记事本改为事件驱动解锁并跨场景持久（`IllusionManager.notebook_unlocked`）；`StageFade.gd`（Autoload 黑屏过渡）；`StoryRoot.gd`/`Stage3Root.gd`
- [ ] 各关难度/手感逐关校准（用户测试反馈中）
- [ ] 旋转关卡手感（Q5/Q6）最终验收
- [ ] 解密模式音效
- [ ] 剧情模式音效、阶段3手感与演出细节收尾打磨

---

## 附录：旋转参考系系统设计规格（v2，2026-08-13 确认）

### 目标
3-1 / 3-2 重构为"平台 + 悬浮圆盘"新关卡，核心为**双参考系切换**玩法。

### 两大参考系
| 参考系 | 玩家受力 | 视角 |
| :--- | :--- | :--- |
| 横向加速度参考系（默认） | 横向虚假力 + 输入力 + 跳跃微重力 | 正常横向视角 |
| 旋转参考系（核心为静止） | 输入力（A/D切向、W/S径向）+ 惯性力（离心 ω²r、科里奥利 -2ω×v_rel），**无重力、无跳跃** | 摄像机随盘旋转（Model B：转盘屏显静止、角色屏显固定；**可选脚指向核心 rot_feet_to_core**）；滚轮缩放视野 |

### 完整流程
1. **横向参考系**：玩家靠近悬浮圆盘（切换区）→ 提示【系统】：检测到参考系出现较大偏差，建议切换参考系
2. **按 Shift 触发参考系切换**（判定：本次洞察位置与上次在不同参考系影响范围 且 操作模式改变）→ 洞察**无时间限制**，持续到同步
3. 切换洞察显示：**玩家输入（蓝）+ 惯性力（红）+ 目标向心力（金，=ω²r 向心）+ 合力（紫=蓝+红）**；操作立即变 A/D 切向、W/S 径向；玩家**继承当前速度换算极坐标**，调节输入
4. **同步成功**（相对速度≈0）→ 提示【系统】：达到参考系对应强度，参考系切换完成，已自动退出解析模式。→ 自动退出洞察 + **拒绝输入1s**（核心提供向心力锁定）
5. **旋转参考系内**：玩家随盘转（视角恒定，转盘屏显静止、角色屏显固定；滚轮缩放视野），移动产生**科里奥利/离心惯性力（新幻觉场，实时算 G 显示）**；洞察显示 输入(蓝)+惯性力(红)+系统阻力(绿=圆盘向心力)；动态平衡；**安全环**（某半径，核心额外供力，松手不被甩）
6. **脱离圆盘** → 提示【系统】：检测到当前参考系偏差较大，已自动恢复原参考系 + 调回横向参考系

### 洞察双模式
| 模式 | 触发 | 能量 |
| :--- | :--- | :--- |
| 普通洞察 | 非切换场景 / 已同步后按Shift | 旋转区：恢复2s / 持续3s；其他默认1s |
| 参考系切换 | 跨参考系按Shift | 无时间限制（直到同步） |

### 关卡设定
- 3-1（教学）：出口在**圆盘上**（随盘转），学会进入+同步+盘上移动
- 3-2（进阶）：出口**需被甩出到达**（圆盘外平台），考验惯性力对抗与甩射
- 圆盘**悬浮式**（平台下方/上方衔接）

### 旋转参考系物理
- 圆盘速度 disk_v = (-ω·R.y, ω·R.x)
- 相对速度 v_rel = velocity − disk_v
- 惯性力：离心 ω²·R + 科里奥利 (2ω·v_rel.y, −2ω·v_rel.x)
- 同步判定：|v_rel| < 阈值

---

> 文档版本：v3.1（开发状态记录，2026-08-15：飞船背景金属科幻化 + 全局字体 fusion-pixel）
> 说明：每次开发迭代后更新本文件。
