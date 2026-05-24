# 操作逻辑文档

本文档记录 Poemery 当前主要交互、状态流和页面跳转逻辑。

## 状态入口

根状态在 `Poemery/ContentView.swift`：

- `library`：`PoemLibraryStore`，负责读取和查询诗词数据。
- `session`：`ReadingSessionStore`，负责当前阅读、队列、收藏和最近阅读。
- `selectedTab`：当前 tab。
- `lastContentTab`：最近一次非搜索 tab，用于关闭搜索后返回原页面。
- `presentedItem`：当前 sheet 展示对象，可能是诗词详情或诗单详情。
- `discoverSearchText`：新发现页内搜索文本。
- `tabSearchText`：系统搜索 tab 的搜索文本。

根视图通过 `PresentedLibraryItem` 区分两类 sheet：

- `.poem(Poem.ID, ReadingQueue)`：打开诗词详情页。
- `.collection(PoemCollection)`：打开诗单详情页。

## Tab 切换逻辑

主 tab：

- 主页
- 新发现
- 资料库
- 我的
- 搜索

当 `selectedTab` 改变时，如果新 tab 不是搜索，`lastContentTab` 会更新为该 tab。搜索页关闭时会把 `selectedTab` 设回 `lastContentTab`。

iOS 26：

- 使用原生 `Tab`。
- 搜索使用 `role: .search`。
- 当前阅读条使用 `tabViewBottomAccessory`。
- 搜索激活使用 `tabViewSearchActivation(.searchTabSelection)`。
- tabbar 滚动最小化使用 `tabBarMinimizeBehavior(.onScrollDown)`。

iOS 18-25 / iOS 17：

- 当前阅读条通过 `safeAreaInset(edge: .bottom)` 作为 fallback。
- iOS 17 使用传统 `.tabItem`。

## 打开诗词

统一入口：

```swift
openPoem(_ poem: Poem, queue: ReadingQueue)
```

流程：

1. 调用 `session.startReading(poem, in: queue)`。
2. `ReadingSessionStore` 设置当前队列，并将作品标记为最近阅读。
3. 根视图设置 `presentedItem = .poem(...)`。
4. SwiftUI sheet 展示 `PoemDetailView`。

所有列表、横向 shelf、搜索结果、作者入口和诗单详情最终都走这个模型：打开一首作品时必须带上一个 `ReadingQueue`。

## 阅读队列

队列模型是 `ReadingQueue`：

- `id`
- `title`
- `poemIDs`

队列来源：

- 单首作品：`ReadingQueue.singlePoem(_:)`。
- 诗单：队列标题为诗单标题，内容为诗单内所有作品。
- 作者结果：队列标题为作者名，内容为该作者作品。
- 搜索结果：队列标题为“搜索结果”。
- 资料库入口：队列标题按入口设置，例如“诗词”“收藏”“最近阅读”。

`ReadingSessionStore.startReading(_:in:)` 会检查队列是否包含当前作品。如果不包含，会退回单首队列，避免队列状态和当前作品不一致。

## 当前阅读条

当前阅读条读取：

```swift
session.currentPoem(in: library)
session.currentQueue
session.canMoveInCurrentQueue
```

交互：

- 点击作品区域：调用 `openCurrentPoem()`，打开当前作品详情。
- 点击下一首：调用 `moveToNextPoem()`，由 session 在当前队列内前进。
- 无当前作品时：显示开始阅读提示，不触发具体作品跳转。

队列切换是循环的：下一首超过末尾时回到第一首。

## 诗词详情页

文件：`Poemery/Views/Shared/PoemDetailView.swift`

初始化参数：

- `initialPoemID`
- `queue`
- `library`
- `session`

详情页内部状态：

- `currentPoemID`：当前正在详情页显示的作品 id。
- `selectedAnnotation`：当前打开的注解 sheet。

显示作品 `visiblePoem` 的兜底顺序：

1. `library.poem(id: currentPoemID)`
2. `session.currentPoem(in: library)`
3. `library.poems.first`

进入详情页时：

- `onAppear` 调用 `session.startReading(visiblePoem, in: queue)`。
- 因此详情页打开也会刷新当前阅读和最近阅读。

详情页操作：

- 关闭：dismiss sheet。
- 收藏：`session.toggleFavorite(visiblePoem)`。
- 上一首/下一首：底部 toolbar 调用 `movePoem(by:)`。
- 横向滑动正文：左滑下一首，右滑上一首。
- 点击注解 term：打开 `AnnotationDetailSheet`。
- 点击相关诗词：使用相关诗词自身队列切换当前详情页内容。

底部状态文案：

- 使用队列短标题和位置，例如“唐诗三 1 / 366”。
- 队列标题超过 4 个字符会截断到前 4 个字符。

## 诗单详情页

文件：`Poemery/Views/Shared/CollectionDetailView.swift`

打开入口：

```swift
openCollection(_ collection: PoemCollection)
```

流程：

1. 根视图设置 `presentedItem = .collection(collection)`。
2. sheet 展示 `CollectionDetailView`。
3. 详情页根据 `library.poems(for: collection)` 得到作品列表。
4. 点击作品时创建 `ReadingQueue(title: collection.title, poems: poems)` 并调用 `onOpenPoem`。

诗单详情页只负责展示集合和作品列表，不直接修改 session。

## 搜索逻辑

新发现页搜索：

- 使用自定义 `SearchField`。
- 文本绑定到 `discoverSearchText`。
- 输入为空显示发现内容。
- 输入非空调用 `library.search(searchText)`。

系统搜索 tab：

- 使用 `.searchable(...)`。
- 文本绑定到 `tabSearchText`。
- `isSearchPresented` 在 `onAppear` 设置为 true。
- 向下拖动超过阈值会调用 `closeSearch()`：
  - 收起系统搜索。
  - 调用 `dismissSearch()`。
  - 回到 `lastContentTab`。

搜索结果：

- 诗词结果使用 `PoemListSection`。
- 作者结果点击后打开该作者第一首作品，并用作者全部作品作为队列。
- 合集结果点击后打开诗单详情。

## 收藏逻辑

收藏状态保存在 `ReadingSessionStore.favoritePoemIDs`。

切换流程：

1. 如果作品 id 已存在，则移除。
2. 如果不存在，则插入到数组头部。
3. 写入 `UserDefaults`。

显示位置：

- 诗词详情页右侧圆形收藏按钮。
- 资料库“收藏”计数。
- 我的页收藏指标和收藏列表。

## 最近阅读逻辑

最近阅读由 `markRecent(_:)` 更新。

触发时机：

- 打开诗词。
- 详情页 `onAppear`。
- 在详情页或当前阅读条切换下一首/上一首。

规则：

- 当前作品 id 设置为 `currentPoemID`。
- 从最近阅读数组中移除旧位置。
- 插入数组头部。
- 最多保留 20 条。
- 写入 `UserDefaults`。

## 资料库入口逻辑

`LibraryScreen` 的列表入口是快速入口：

- 诗单：打开第一个诗单。
- 诗人：打开第一个作者的第一首作品。
- 诗词：打开诗库第一首作品，队列为全部作品。
- 收藏：有收藏则打开第一首收藏；无收藏则回退到诗库第一首。
- 最近阅读：有最近阅读则打开第一首最近阅读；无最近阅读则回退到诗库第一首。

当前没有“诗人完整列表页”或“收藏完整列表页”，这些入口先保证有可用跳转。

## 我的页逻辑

`ProfileScreen` 完全基于本地状态生成：

- 收藏数量：`session.favoritePoems(in: library)`。
- 最近阅读数量：`session.recentPoems(in: library)`。
- 诗库数量：`library.poems.count`。
- 作者数量：`library.authors().count`。
- 常读作者：统计最近阅读中的作者频次。
- 常读体裁：统计最近阅读中的体裁频次。

如果没有最近阅读，偏好区域显示“暂无记录”。

## 注解逻辑

`PoemTextSection` 会读取每一行对应的 `PoemAnnotation`。

当前导入数据中 annotations 为空，因此大多数作品不会出现注解按钮。数据结构和 `AnnotationDetailSheet` 已准备好，后续只需要在数据里补充注解即可显示。

## 当前限制

- 当前“阅读”是文本阅读状态，不是真实音频播放。
- 当前阅读条只有下一首，没有播放/暂停音频状态。
- 详情页队列切换基于当前传入队列，不跨不同诗单自动混合。
- 收藏和最近阅读只在本机保存。
- 搜索是本地字符串匹配，没有拼音、繁简转换或语义搜索。
