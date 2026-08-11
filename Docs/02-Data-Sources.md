# 数据来源文档

本文档记录 Poemery 当前数据来源、导入流程、运行时数据结构和本地持久化策略。

## 数据总览

打包主数据由 `Poemery/PoemLibrary.sqlite` 和 `Poemery/PoemsSeed.json` 组成，均由 `Scripts/import_chinese_poetry.py` 生成。运行时优先读取 SQLite，JSON 作为兼容 fallback；随后合并代码内的小型精选增强层。

当前数据规模：

- 打包主库：12842 首/条/篇，含重新生成的诗单和分类。
- 运行时目录：至少 12848 首/条/篇，并增加精选诗单和分类；按 `canonicalKey` 去重。

打包主库朝代统计：唐 366、宋 280、五代 542、清 258、元 11055、先秦 341。精选增强层另加入宋、汉、魏晋、南北朝、明、清代表作，因此运行时浏览可覆盖更多朝代。

主要体裁包括唐诗各类近体/古体、宋词、元曲、先秦诗与典籍，以及精选层中的汉魏古诗、南北朝民歌、五代词、明清诗词。

## 上游来源

数据来自开源仓库：

`https://github.com/chinese-poetry/chinese-poetry`

固定 commit：

`99ebbef7e1345c0985c44b9fd96a3f9e776f117b`

使用的上游文件：

- 唐诗三百首：`全唐诗/唐诗三百首.json`，上游 366 条。
- 宋词三百首：`宋词/宋词三百首.json`，上游 280 条。
- 花间集：`五代诗词/huajianji/huajianji-1-juan.json` 至卷九及卷十 `huajianji-x-juan.json`，共 497 条。
- 南唐词：`五代诗词/nantang/poetrys.json`，45 条。
- 纳兰性德诗词：`纳兰性德/纳兰性德诗集.json`，258 条，其中 1 条空标题以“无题”收录。
- 元曲：`元曲/yuanqu.json`，上游 11057 条，其中 2 条空正文被跳过，最终进入 App 11055 条。
- 论语：`论语/lunyu.json`，上游 20 条，按篇进入 App。
- 诗经：`诗经/shijing.json`，上游 305 条，按篇进入 App。
- 四书五经：`四书五经/daxue.json`、`四书五经/mengzi.json`、`四书五经/zhongyong.json`，上游共 16 条，按篇进入 App。

版权与许可说明在 `Poemery/ChinesePoetryNotice.txt`。上游仓库代码和仓库整体标注 MIT，但 README 同时说明数据整理自互联网，因此不能仅凭仓库许可推断所有现代整理文本在所有法域均无风险。App 不复制商业诗词网站的现代译文、赏析、简介或图片。

五代与清代候选已完成数量和字段核验并并入打包主库。花间集和南唐数据中的 `notes` 暂不导入，因为其现代整理来源链仍需进一步确认；纳兰集中已知一组相同正文以不同标题出现，导入器通过包含标题的稳定内容 id 保留上游两条记录。

## 精选增强层

`PoemLibraryStore` 在读取打包目录后合并 `curatedCatalog()`：

- 按规范化 `canonicalKey` 去重；若主库已有同一作品，保留原 id，避免既有诗单引用失效。
- 首批代表作覆盖汉、魏晋、南北朝、五代、明、清，并补充王安石《元日》。
- 古典原文按公版文本处理，校订说明写入 `sourceName` / `sourceLicense`。
- 拼音、注释、白话译文和赏析只使用 Poemery 原创编辑内容；当前首批完整增强覆盖《元日》。

## 导入脚本

导入脚本：`Scripts/import_chinese_poetry.py`

主要职责：

- 从固定 commit 的 GitHub raw URL 读取上游 JSON，遇到不完整响应时有限重试并指数退避。
- 校验每个上游源的期望数量；多卷来源在合并后校验总数。
- 清理标题、作者、正文段落中的首尾空白。
- 为缺失标题/作者设置兜底值，例如“无题”“佚名”。
- 对元曲中部分标题带正文的空段落条目做修复。
- 跳过无法修复的空正文条目。
- 生成稳定的 `Poem.id`：根据来源、作者、标题和正文计算 SHA-256 摘要。
- 合并标签并推断唐诗体裁。
- 生成 `sourceURL` 指向固定 commit 的 GitHub blob 页面。
- 根据来源和作品 id 生成 `ArtworkStyle`，用于本地封面视觉。
- 生成诗单、分类和数据来源 notice。
- 校验作品 id 唯一、行号连续、诗单引用有效、分类能命中作品。
- JSON、notice 和 SQLite 先写入临时文件，全部生成和校验成功后再替换正式资源，避免半成品状态。

默认输出：

- `Poemery/PoemsSeed.json`
- `Poemery/ChinesePoetryNotice.txt`

## App 数据模型

模型定义在 `Poemery/Models/Poem.swift`。

### Poem

`Poem` 是作品主体：

- `id`：稳定唯一 id。
- `title`：标题。
- `author`：作者。
- `dynasty`：朝代。
- `form`：体裁。
- `tags`：题材、来源、体裁等标签。
- `summary`：来源说明型摘要，目前是导入脚本生成的通用摘要。
- `lines`：正文行数组。
- `annotations`：注解数组，当前导入数据默认为空。
- `sourceURL`：上游来源链接。
- `artworkStyle`：本地封面样式。

派生属性：

- `fullText`：将所有正文行用换行合并，用于搜索。
- `displayArtist`：格式为“朝代 · 作者”。
- `annotations(for:)`：按正文行查找注解。

### PoemLine

`PoemLine` 表示正文行：

- `id`：行 id。
- `order`：行序号。
- `text`：正文。

### PoemAnnotation

`PoemAnnotation` 表示注解：

- `id`
- `lineID`
- `term`
- `reading`
- `summary`
- `detail`

打包主库当前没有现代注解；精选增强层可以逐首加入经审校的 `PoemAnnotation`。

### PoemSupplement

`Poem.supplement` 是可选增强对象，旧 JSON 和旧 SQLite 不需要迁移：

- `pronunciations`：按 `lineID` 关联逐行拼音。
- `translation`：白话译文。
- `appreciation`：赏析。
- `sourceName`、`sourceURL`、`sourceLicense`：增强内容的独立来源与许可。

简繁切换会转换译文、赏析和来源名称，但不会转换拼音。没有 supplement 的作品不会在详情页出现空区域。

### PoemCollection

`PoemCollection` 表示诗单或合集：

- `id`
- `title`
- `subtitle`
- `kind`
- `poemIDs`
- `accent`

`kind` 当前支持：

- `featured`
- `mood`
- `author`
- `era`
- `chart`

当前实际数据主要使用 `featured`、`chart`、`author`。

### PoemCategory

`PoemCategory` 表示浏览题材：

- `id`
- `title`
- `subtitle`
- `tag`
- `artworkStyle`
- `symbol`

分类匹配逻辑不只看 tags，也会匹配朝代、体裁和作者。

## 运行时数据加载

服务定义在 `Poemery/Services/PoemLibraryStore.swift`。

`PoemLibraryStore` 是主数据入口：

- `bootstrap()` 同步建立极小精选目录，让主界面无需等待完整诗库。
- `loadBundled()` 在 detached task 中优先读取 `PoemLibrary.sqlite`，失败后读取 `PoemsSeed.json`。
- 主库与精选增强层去重合并后再做简繁转换，并建立 id、作者、题材、热门度与全文 gram 索引。
- 后台加载完成后由 `ContentView` 替换 bootstrap store；失败时继续保留精选目录。

如果 Bundle 中两种主数据都不可用，正常异步加载会报错；UI 仍可使用代码内 bootstrap 内容并提供重试。

## 搜索数据

搜索入口是 `PoemLibraryStore.search(_:)`。

搜索流程：

- 对用户输入做 trim、lowercase，并按空格切分 token。
- 空 token 返回空结果。
- 诗词搜索字段包括标题、作者、朝代、体裁、全文、tags、themes 和来源元数据。
- 诗单搜索字段包括标题和副标题。
- 作者搜索字段包括作者名和朝代。
- 所有 token 必须都命中，才进入结果。

作者别号和繁简字形仍有有限的本地别名转换。按用户要求，主题同义词扩展、模糊主题分类和语义相关性排序本轮暂不实现；当前只匹配实际写入作品的字段。

搜索结果结构是 `SearchResults`：

- `poems`
- `authors`
- `collections`

## 诗人画像

首批新增诗人画像使用 Wikimedia Commons 逐文件核验的公版传统画像。模型保存图片 URL、文件页 URL、credit 和许可；诗人页通过 `AsyncImage` 按需加载并显示来源链接。画像是后世传统画像，不应描述为真实摄影肖像。

远程请求会向 Wikimedia 暴露常规网络信息（如 IP 和 User-Agent），但不会上传收藏、最近阅读或诗库内容。离线时自动使用本地首字封面。

## 用户本地数据

运行时阅读状态定义在 `Poemery/Services/ReadingSessionStore.swift`。

持久化使用 `UserDefaults`：

- 收藏 key：`poemery.favoritePoemIDs`
- 最近阅读 key：`poemery.recentPoemIDs`

不持久化的数据：

- `currentPoemID`
- `currentQueue`

收藏与最近阅读只保存作品 id。实际显示时通过 `PoemLibraryStore` 把 id 还原成 `Poem`。

最近阅读最多保留 20 条，新的阅读会移动到队首。

## 当前限制

- 数据是打包时静态数据，没有运行时联网同步。
- 主库的现代注解、译文、赏析覆盖率仍很低，目前采用逐首审校的精选增强策略。
- `summary` 多数仍是来源说明；只有精选作品包含逐首编辑摘要。
- 主题同义词模糊匹配和语义检索按产品决定延期。
- 收藏和最近阅读是本机本地状态，没有账号和云同步。
