# 数据来源文档

本文档记录 Poemery 当前数据来源、导入流程、运行时数据结构和本地持久化策略。

## 数据总览

主数据文件是 `Poemery/PoemsSeed.json`，由 `Scripts/import_chinese_poetry.py` 生成并随 App Bundle 打包。

当前数据规模：

- 诗词作品：11701 首/条。
- 诗单合集：7 个。
- 浏览分类：7 个。

按朝代统计：

- 唐：366 首。
- 宋：280 首。
- 元：11055 条。

按主要体裁统计：

- 唐诗相关：五言绝句、七言绝句、五言律诗、七言律诗、五言古诗、七言古诗、乐府、诗。
- 宋词：词。
- 元曲：曲。

## 上游来源

数据来自开源仓库：

`https://github.com/chinese-poetry/chinese-poetry`

固定 commit：

`99ebbef7e1345c0985c44b9fd96a3f9e776f117b`

使用的上游文件：

- 唐诗三百首：`全唐诗/唐诗三百首.json`，上游 366 条。
- 宋词三百首：`宋词/宋词三百首.json`，上游 280 条。
- 元曲：`元曲/yuanqu.json`，上游 11057 条，其中 2 条空正文被跳过，最终进入 App 11055 条。

版权与许可说明在 `Poemery/ChinesePoetryNotice.txt`。上游仓库使用 MIT License。App 保留上游文本形态，不加入第三方网站的现代赏析、译文或讲解。

## 导入脚本

导入脚本：`Scripts/import_chinese_poetry.py`

主要职责：

- 从固定 commit 的 GitHub raw URL 读取上游 JSON。
- 校验每个上游源的期望数量。
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

当前导入脚本未从上游生成现代注解，结构是为后续扩展保留。

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

- 初始化时从 App Bundle 读取 `PoemsSeed.json`。
- 使用 `JSONDecoder` 解码为 `PoemSeedCatalog`。
- 建立 `poemsByID` 字典，提高按 id 查找效率。
- 提供诗单、分类、作者聚合和搜索能力。

如果 Bundle 中缺少 `PoemsSeed.json` 或解码失败，会触发 assertion 并回退到内置的最小数据集：一首《静夜思》。这个 fallback 只用于开发和容错，不是正常内容来源。

## 搜索数据

搜索入口是 `PoemLibraryStore.search(_:)`。

搜索流程：

- 对用户输入做 trim、lowercase，并按空格切分 token。
- 空 token 返回空结果。
- 诗词搜索字段包括标题、作者、朝代、体裁、全文和 tags。
- 诗单搜索字段包括标题和副标题。
- 作者搜索字段包括作者名和朝代。
- 所有 token 必须都命中，才进入结果。

搜索结果结构是 `SearchResults`：

- `poems`
- `authors`
- `collections`

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
- 现代注解、译文、赏析暂未从上游生成。
- `summary` 目前是来源说明，不是逐首作品的文学赏析。
- 收藏和最近阅读是本机本地状态，没有账号和云同步。
