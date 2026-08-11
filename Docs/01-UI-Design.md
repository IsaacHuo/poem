# 界面设计文档

本文档记录 Poemery 当前 SwiftUI 界面设计。设计目标是把诗词内容放进 Apple Music 式的信息架构中：大标题、横向推荐、诗单封面、列表浏览、资料库、独立搜索入口，以及底部系统级玻璃附件。

## 设计原则

- 内容语义全部面向诗词歌赋：作品称为“诗词”或“作品”，集合称为“诗单”或“合集”，作者称为“诗人/作者”，个人区称为“我的”。
- 底部导航尽量使用系统能力，不自绘 tabbar。iOS 26 使用 `Tab`、`TabRole.search`、`tabViewBottomAccessory`、`tabViewSearchActivation` 和 `tabBarMinimizeBehavior`；旧系统走 `TabView` 与 `safeAreaInset` fallback。
- 视觉上参考 Apple Music 的信息密度和操作层级，但不复制 Apple Music 品牌、Apple 标识或音乐版权内容。
- 页面主体保持明亮、纸感、低噪声：大标题、留白、轻量玻璃容器、诗词卡片和可读性优先的中文排版。

## 全局视觉系统

主要定义在 `Poemery/Design/PoemeryTheme.swift`：

- 主题色：朱红色 `accent` 用于选中态、重点按钮、收藏和分类强调。
- 背景：`background` 是接近纸白的浅色；`surface`、`groupedBackground` 用于列表和卡片。
- 文本：`primaryText`、`secondaryText`、`tertiaryText` 明确区分标题、说明和弱信息。
- 字体：中文正文通过 `HYWenRunSongYun-U` 自定义字体呈现，入口是 `PoemeryTheme.chineseFont(...)`。
- 动效：主动画 `motion` 和快速动画 `quickMotion` 使用 SwiftUI smooth 动画，避免重型自定义动画。

玻璃材质定义在：

- `Poemery/Design/AdaptiveGlassSurface.swift`
- `Poemery/Views/Shared/GlassContainerModifier.swift`

iOS 26 使用 `.glassEffect(...)` / `GlassEffectContainer`，低版本 fallback 到 `.ultraThinMaterial`、描边和阴影。

## 根容器与底部区域

根视图是 `Poemery/ContentView.swift`。

启动时同步创建仅含少量精选作品的 `PoemLibraryStore.bootstrap()`，立即渲染可操作的 Tab 界面。完整 SQLite/JSON 诗库在后台读取并建立索引；加载期间顶部仅显示非阻塞状态条，加载失败也保留精选内容和重试入口，不再展示阻塞式全屏 loading。

当前主导航结构：

- `主页`
- `新发现`
- `资料库`
- `我的`
- `搜索`

iOS 18+ 使用 SwiftUI `Tab` API。搜索 tab 使用 `role: .search`，因此在 iOS 26 上由系统呈现为独立搜索入口，而不是自定义圆形按钮。iOS 26 同时使用：

- `tabViewBottomAccessory`：承载当前阅读条。
- `tabViewSearchActivation(.searchTabSelection)`：选择搜索入口后进入系统搜索 tab 行为。
- `tabBarMinimizeBehavior(.onScrollDown)`：滚动时让底栏按系统规则最小化。

iOS 18-25 和 iOS 17 fallback：

- 主体仍使用系统 `TabView`。
- 当前阅读条通过 `safeAreaInset(edge: .bottom)` 放置。
- 材质使用 `.ultraThinMaterial`。

## 当前阅读条

当前阅读条由 `ReadingTabAccessory` 与 `ReadingAccessoryContent` 实现，位于 `ContentView.swift` 下方。

状态分两类：

- 有当前诗词：显示封面、标题、作者/队列信息，以及“下一首”按钮。
- 无当前诗词：显示“打开一首诗 / 当前阅读会显示在这里”或 inline 状态下的“开始阅读”。

iOS 26 下根据 `tabViewBottomAccessoryPlacement` 自动切换：

- expanded：显示较完整的诗词信息。
- inline：压缩为一行，适应系统底栏最小化状态。

## 页面设计

### 主页

文件：`Poemery/Views/Tabs/HomeScreen.swift`

结构：

- `ScreenHeader`：大标题“主页”，副标题“诗词歌赋，为你继续阅读”。
- `FeaturedCarousel`：横向诗单推荐。
- `PoemShelf`：最近阅读，空状态时使用前几首作品兜底。
- `PoemListSection`：开始阅读。
- `PoemShelf`：为你推荐。
- `AuthorShelf`：作者精选。

主页承担 Apple Music “Home / Listen Now” 的角色，重点是继续阅读、推荐内容和个人化入口。

### 新发现

文件：`Poemery/Views/Tabs/DiscoverScreen.swift`

结构：

- 大标题“新发现”。
- 新诗单、新诗精选和浏览题材。
- 点击题材会切换到系统搜索 tab，并把题材名作为搜索词。

这个页面对应 Apple Music “Browse / New” 的模式，负责探索集合和题材；全局检索统一由系统搜索 tab 承担。

### 资料库

文件：`Poemery/Views/Tabs/LibraryScreen.swift`

结构：

- 大标题“资料库”。
- 玻璃列表入口：诗单、诗人、诗词、收藏、最近阅读。
- 最近添加横向诗词 shelf。
- 全部诗单列表。
- 二级目录：全部诗单、诗人、诗词、收藏、最近阅读。

资料库的交互是“进入完整目录后再选择作品或诗单”，所有作品打开时都会带上对应阅读队列。

### 我的

文件：`Poemery/Views/Tabs/ProfileScreen.swift`

结构：

- 大标题“我的”。
- 本地档案卡：收藏、最近阅读、诗库。
- 设置与隐私入口：数据来源、隐私说明、本机记录清理和显示信息。
- 阅读偏好：根据最近阅读统计常读作者和常读体裁。
- 收藏列表、最近阅读列表和常用诗单。

这里是免费离线的本地阅读档案，不需要账号、订阅或云端状态。

### 搜索

搜索页目前是 `ContentView.swift` 内的私有 `SearchScreen`。

结构：

- `NavigationStack` + 大标题“搜索”。
- 系统 `.searchable(...)`，prompt 为“诗人、诗词、句子、题材”。
- 空搜索时显示“推荐搜索”。
- 有搜索词时显示诗词、作者、合集结果。
- 向下拖动搜索页会收起搜索并回到上一个内容 tab。

### 诗词详情页

文件：`Poemery/Views/Shared/PoemDetailView.swift`

结构：

- compact hero：小封面、标题、作者朝代体裁、标签、收藏按钮。
- 正文：`PoemTextSection`，补充数据存在时在诗句下显示拼音。
- 增强内容：按数据条件显示译文、赏析和内容来源；没有资料时不显示空 section。
- 注释：点击正文下方词语标签打开详细注释。
- 相关诗词：按共享标签筛选。
- 底部工具栏：上一首、当前队列位置、下一首。
- 横向滑动正文区域可切换上一首/下一首。

详情页不是重型“播放器”，而是以阅读为中心的沉浸式正文页。

### 诗单详情页

文件：`Poemery/Views/Shared/CollectionDetailView.swift`

结构：

- 大封面 `CollectionCover`：渐变、纸纹、诗境标记和集合 glyph，不在封面内重复可能很长的完整标题。
- 封面外展示完整标题、副标题、作品数量。
- 作品列表。

诗单详情页对应 Apple Music 专辑/歌单详情的信息结构，但内容语义是诗单和作品。

### 诗人详情页

文件：`Poemery/Views/Shared/CollectionDetailView.swift`

- 使用接近 Apple Music Artist 页的大幅 hero：传统画像、底部渐变、诗人姓名、朝代和作品数。
- 首批画像来自 Wikimedia Commons 逐文件核验的公版传统画像，hero 下方提供可点击来源与许可信息。
- 图片通过 `AsyncImage` 懒加载，不参与诗库启动流程；离线、加载中或失败时使用首字渐变意境 fallback。
- 作者简介来自本地编辑元数据；未知作者继续使用包含朝代和收录数量的通用说明。

## 共享组件

主要共享组件：

- `ScreenHeader`：页面大标题和副标题。
- `SectionTitle`：分区标题，可带 chevron。
- `FeaturedCarousel` / `FeaturedCollectionCard`：横向推荐诗单。
- `PoemShelf` / `CompactPoemCard`：横向作品 shelf。
- `PoemListSection` / `PoemListRow`：列表型作品入口。
- `CategoryTile`：题材入口。
- `PoemArtwork`：用 `ArtworkStyle` 生成意境封面，只显示标题首个 CJK 字符，不把完整长标题压进小封面。
- `PaperTexture`：轻量纸纹装饰。
- `EmptyLibraryState`：空状态。

## 适配与约束

- 最低系统保持 iOS 17。
- iOS 26 优先使用系统原生 Liquid Glass 和底栏 API。
- iOS 17-25 不追求完全复刻 iOS 26 形态，而是保留稳定可用的系统 `TabView`、`safeAreaInset` 和 material fallback。
- 诗词和诗单封面仍完全由本地 `ArtworkStyle` 生成。部分诗人页会按需请求 Wikimedia Commons 公版传统画像；请求失败不会影响浏览和阅读。
- App Icon 使用 1024×1024、无 Alpha 的全幅源图，外部白色遮罩已去除，最终圆角由 iOS 系统生成。
