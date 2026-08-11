# 诗库增强调查与实施记录

更新日期：2026-08-10

## 目标与执行顺序

本轮调查围绕启动体验、朝代覆盖、诗词增强内容、诗人资料、封面和图标展开。执行优先级：

1. 首屏立即进入，完整诗库后台加载。
2. 通过可审校精选层扩展汉、魏晋、南北朝、五代、明、清。
3. 建立兼容旧目录的拼音、注释、译文、赏析模型和 UI。
4. 诗人页升级为大幅 hero，并为真实图片建立逐文件许可记录。
5. 小封面改用首字意境，避免长标题缩得过小。
6. 修复 App Icon 源图白色外部遮罩。
7. 更新测试、文档并执行构建验证。

主题同义词模糊匹配和语义搜索原在调查范围内，后按产品决定延期。本轮没有加入针对“新年”或《元日》的搜索特判。

## 数据架构决策

采用“打包主库 + 精选增强层”而不是立即覆盖生成 12,000 条资源：

- 打包 SQLite/JSON 继续作为稳定主目录，并已扩展到 12,842 条。
- 小型精选层在运行时按 `canonicalKey` 合并并去重。
- 如果增强作品已存在，保留主库 id，防止旧诗单引用断裂。
- supplement 为可选字段，旧 JSON 与 SQLite schema 可继续工作。
- 缺少增强资料时不显示空的拼音、译文或赏析区域。

该方案能先交付更多朝代和高质量详情，同时避免把未经核验的网络整理内容整体写入 App。

## 古典诗词上游核验

固定仓库：

- 仓库：<https://github.com/chinese-poetry/chinese-poetry>
- commit：`99ebbef7e1345c0985c44b9fd96a3f9e776f117b`
- 仓库许可证：MIT

已确认的扩展候选：

- `五代诗词/huajianji/huajianji-1-juan.json` 至 `huajianji-9-juan.json`、`huajianji-x-juan.json`
- `五代诗词/nantang/poetrys.json`
- `五代诗词/nantang/authors.json`
- `纳兰性德/纳兰性德诗集.json`（固定 commit 实测 258 条）

风险说明：上游 README 表明数据整理自互联网。因此仓库 MIT 声明不能自动消除所有现代标点、注释、整理文本的权利风险。尤其是 `notes` 等现代注释，不应在没有进一步来源链和权利判断时批量导入。本轮已导入 497 条花间词、45 条南唐词和 258 条纳兰诗词正文，但刻意忽略上游 `notes`；精选层只使用古典公版原文和 Poemery 原创编辑内容。

## 首批精选内容

运行时精选层覆盖：

- 宋：王安石《元日》
- 汉：曹操《观沧海》
- 魏晋：陶渊明《饮酒·其五》
- 南北朝：佚名《敕勒歌》
- 五代：李煜《虞美人·春花秋月何时了》
- 明：于谦《石灰吟》
- 清：龚自珍《己亥杂诗·其五》
- 清：纳兰性德《长相思·山一程》

《元日》作为首批完整增强样本，包含逐行拼音、词语注释、白话译文和赏析。它不是搜索引擎的特殊分支；后续作品可以使用同一模型逐首增加资料。

## 诗人传统画像

以下 Wikimedia Commons 文件页已逐文件核验为公版传统画像。它们是后世画像，不是摄影肖像：

| 诗人 | 文件页 | 作者/来源摘要 | 状态 |
| --- | --- | --- | --- |
| 王安石 | <https://commons.wikimedia.org/wiki/File:Wang_Anshi.jpg> | 作者不详，清宫旧藏 | Public domain |
| 曹操 | <https://commons.wikimedia.org/wiki/File:Cao_Cao_scth.jpg> | 王圻《三才图会》 | Public domain |
| 陶渊明 | <https://commons.wikimedia.org/wiki/File:%27Tao_Yuanming%27,_ink_on_paper_scroll_by_Min_Zhen,_18th_century_china.jpg> | 闵贞绘，18 世纪 | Public domain |
| 李煜 | <https://commons.wikimedia.org/wiki/File:Li_Yu_scth.jpg> | 王圻《三才图会》 | Public domain |
| 于谦 | <https://commons.wikimedia.org/wiki/File:Yu_Qian_by_Gu_Jianlong.jpg> | 顾见龙绘 | Public domain |
| 龚自珍 | <https://commons.wikimedia.org/wiki/File:Gong_Zizhen.jpg> | 清人绘，作者不详 | Public domain |
| 纳兰性德 | <https://commons.wikimedia.org/wiki/File:Yu_Zhiding%27s_portrait_of_Nalan_Xingde_cropped.jpg> | 禹之鼎绘 | Public domain |

实现使用 `Special:FilePath` 作为图片 URL、具体文件页作为 credit 链接。即使公版不强制署名，App 仍显示作者/来源和许可。远程加载会产生对 Wikimedia 的常规网络请求；不上传用户收藏、最近阅读或诗库数据。

## App Icon

源图为 1024×1024 RGB PNG，但四角含有与画布边缘连通的近白色预制遮罩。`Scripts/fix_app_icon.py`：

- 只洪泛标记与画布边缘连通的近白区域，避免误伤卷轴本身；
- 从邻近山水背景延展填充；
- 对修复边界做轻量羽化；
- 输出仍为 1024×1024、RGB、无 Alpha PNG；
- 不修改 `Contents.json`，最终圆角继续由 iOS 系统遮罩。

## 性能策略

- `PoemLibraryStore.bootstrap()` 同步构建少量内容和小索引。
- `ContentView` 第一帧直接显示 Tab，而不是全屏 loading。
- SQLite/JSON 读取、目录合并、简繁转换和完整索引在 detached task 中完成。
- 加载状态仅通过顶部小提示展示；失败后仍可阅读精选内容并重试。
- 诗人网络图片由 `AsyncImage` 在页面出现时加载，不参与启动路径。

当前 SQLite 仍一次性读取主库和建立完整索引。进一步优化可将详情正文与 annotations 改为按 id 查询，或预生成持久化全文索引，但需要 schema 版本升级和性能基准后再实施。

## 验证记录

- Debug iOS Simulator 构建：通过。
- `build-for-testing`：通过，App 与测试目标均成功编译。
- App Icon：已检查为 1024×1024、RGB、无 Alpha，并人工查看修复结果。
- 导入脚本：成功生成 12,842 条 JSON/SQLite，并通过表行数、诗单引用与搜索 gram 校验；独立查询确认两种目录数量一致，五代 542、清 258。
- 完整 `xcodebuild test`：测试目标成功编译并开始运行，但在 180 秒限制内未结束，命令超时；未声称测试通过。

## 后续工作

1. 在决定恢复主题搜索后，先设计通用主题本体和评估集，不写单诗特判。
2. 继续审核花间集、南唐词和纳兰词的现代 `notes` 来源；在权利链明确前不批量导入注释。
3. 为更多高频作品逐首补充原创或明确许可的拼音、注释、译文和赏析。
4. 如需完全离线的诗人画像，将已核验文件下载为本地资源，并保留每张图片的来源清单。
5. 使用 Instruments/MetricKit 测量冷启动和完整索引耗时，再决定是否升级为真正的正文/详情懒加载。
