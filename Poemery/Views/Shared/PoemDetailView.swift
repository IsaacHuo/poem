import SwiftUI
import Photos
import UIKit

struct PoemDetailView: View {
    let initialPoemID: Poem.ID
    let queue: ReadingQueue
    let library: PoemLibraryStore
    let session: ReadingSessionStore

    @Environment(\.dismiss) private var dismiss
    @Environment(\.chineseScriptPreference) private var script
    @State private var currentPoemID: Poem.ID
    @State private var authorPath: [AuthorResult.ID] = []
    @State private var selectedAnnotation: PoemAnnotation?
    @State private var shareComposerItem: PoemShareComposerItem?
    @State private var hasStartedInitialReading = false

    init(
        initialPoemID: Poem.ID,
        queue: ReadingQueue,
        library: PoemLibraryStore,
        session: ReadingSessionStore
    ) {
        self.initialPoemID = initialPoemID
        self.queue = queue
        self.library = library
        self.session = session
        self._currentPoemID = State(initialValue: initialPoemID)
    }

    private var visiblePoem: Poem {
        library.poem(id: currentPoemID)
            ?? session.currentPoem(in: library)
            ?? library.poems.first
            ?? library.poems[0]
    }

    private var currentQueue: ReadingQueue {
        session.currentQueue ?? queue
    }

    private var canMoveInQueue: Bool {
        currentQueue.poemIDs.count > 1
    }

    private var currentQueueIndex: Int? {
        currentQueue.poemIDs.firstIndex(of: visiblePoem.id)
    }

    private var queuePositionText: String {
        guard let currentQueueIndex else {
            return script.converted(currentQueue.title)
        }
        return "\(currentQueueIndex + 1) / \(currentQueue.poemIDs.count)"
    }

    var body: some View {
        NavigationStack(path: $authorPath) {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .center, spacing: 22) {
                        Color.clear
                            .frame(height: 0)
                            .id("reader-top")

                        compactHero

                        poemTextContent
                            .simultaneousGesture(swipeGesture)

                        RelatedPoemsSection(poems: relatedPoems, onOpenPoem: showRelatedPoem)
                            .frame(maxWidth: 680, alignment: .leading)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 18)
                    .padding(.bottom, 56)
                    .frame(maxWidth: .infinity)
                }
                .scrollIndicators(.hidden)
                .background(background)
                .onChange(of: currentPoemID) {
                    selectedAnnotation = nil
                    withAnimation(PoemeryTheme.motion) {
                        proxy.scrollTo("reader-top", anchor: .top)
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.headline.weight(.semibold))
                    }
                    .accessibilityLabel(script.converted("关闭"))
                }

                ToolbarItemGroup(placement: .bottomBar) {
                    Button {
                        movePoem(by: -1)
                    } label: {
                        Image(systemName: "chevron.left")
                    }
                    .disabled(!canMoveInQueue)
                    .accessibilityLabel(script.converted("上一首作品"))

                    Spacer()

                    Text(statusBarText)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(PoemeryTheme.primaryText)
                        .lineLimit(1)
                        .monospacedDigit()
                        .frame(minWidth: 132)
                        .fixedSize(horizontal: true, vertical: false)
                        .accessibilityLabel("\(script.converted(currentQueue.title))，\(queuePositionText)")

                    Spacer()

                    Button {
                        movePoem(by: 1)
                    } label: {
                        Image(systemName: "chevron.right")
                    }
                    .disabled(!canMoveInQueue)
                    .accessibilityLabel(script.converted("下一首作品"))
                }
            }
            .toolbarBackground(.hidden, for: .bottomBar)
            .navigationDestination(for: AuthorResult.ID.self) { authorID in
                if let author = library.author(id: authorID) {
                    PagedAuthorDetailContent(author: author, library: library, onOpenPoem: showAuthorPoem)
                } else {
                    EmptyLibraryState(
                        title: script.converted("未找到作者"),
                        subtitle: script.converted("这个作者条目已经不可用。")
                    )
                        .padding(20)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(PoemeryTheme.background)
                }
            }
            .sheet(item: $selectedAnnotation) { annotation in
                AnnotationDetailSheet(annotation: annotation)
                    .presentationDetents([.medium])
            }
            .sheet(item: $shareComposerItem) { item in
                PoemShareComposer(poem: item.poem)
                    .presentationDetents([.large])
            }
            .onAppear {
                if !hasStartedInitialReading {
                    session.startReading(visiblePoem, in: queue)
                    hasStartedInitialReading = true
                }
            }
            .task(id: "\(currentPoemID)|\(script.rawValue)") {
                await library.loadPoemDetailIfNeeded(id: currentPoemID, script: script)
            }
        }
    }

    @ViewBuilder
    private var poemTextContent: some View {
        if visiblePoem.lines.isEmpty {
            VStack(spacing: 12) {
                ProgressView()
                    .tint(PoemeryTheme.accent)

                Text(script.converted("正在加载正文"))
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(PoemeryTheme.secondaryText)
            }
            .frame(maxWidth: 680, minHeight: 160)
        } else {
            PoemTextSection(
                poem: visiblePoem,
                highlightedLineID: nil,
                selectedAnnotation: $selectedAnnotation
            )
        }
    }

    private var compactHero: some View {
        HStack(alignment: .center, spacing: 14) {
            PoemArtwork(poem: visiblePoem, size: 78, cornerRadius: 12)
                .shadow(color: visiblePoem.displayArtworkStyle.primary.opacity(0.24), radius: 18, x: 0, y: 10)

            VStack(alignment: .leading, spacing: 6) {
                Text(visiblePoem.title)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(PoemeryTheme.primaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.56)

                authorAttribution

                Text(visiblePoem.tags.prefix(3).joined(separator: " · "))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(PoemeryTheme.tertiaryText)
                    .lineLimit(1)
            }
            .layoutPriority(1)

            Spacer(minLength: 8)

            actionButtons
        }
        .frame(maxWidth: 680)
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private var authorAttribution: some View {
        if let visibleAuthor {
            NavigationLink(value: visibleAuthor.id) {
                authorAttributionLabel(showsChevron: true)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(script.converted("查看\(visiblePoem.author)的作者介绍"))
        } else {
            authorAttributionLabel(showsChevron: false)
        }
    }

    private func authorAttributionLabel(showsChevron: Bool) -> some View {
        HStack(spacing: 4) {
            Text(detailAttributionText)
                .lineLimit(1)
                .minimumScaleFactor(0.72)

            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.bold))
                    .imageScale(.small)
            }
        }
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(PoemeryTheme.secondaryText)
    }

    private var actionButtons: some View {
        HStack(spacing: 8) {
            favoriteButton
            shareButton
        }
    }

    private var favoriteButton: some View {
        Button {
            session.toggleFavorite(visiblePoem)
        } label: {
            Image(systemName: session.isFavorite(visiblePoem) ? "heart.fill" : "heart")
                .font(.headline.weight(.bold))
                .foregroundStyle(session.isFavorite(visiblePoem) ? PoemeryTheme.accent : PoemeryTheme.primaryText)
                .frame(width: 42, height: 42)
                .background(.regularMaterial, in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(script.converted(session.isFavorite(visiblePoem) ? "取消收藏" : "收藏"))
    }

    @ViewBuilder
    private var shareButton: some View {
        Button {
            shareComposerItem = PoemShareComposerItem(poem: visiblePoem)
        } label: {
            shareButtonLabel
        }
        .buttonStyle(.plain)
        .accessibilityLabel(script.converted("制作分享图片"))
    }

    private var shareButtonLabel: some View {
        Image(systemName: "square.and.arrow.up")
            .font(.headline.weight(.bold))
            .foregroundStyle(PoemeryTheme.primaryText)
            .frame(width: 42, height: 42)
            .background(.regularMaterial, in: Circle())
    }

    private var background: some View {
        LinearGradient(
            colors: [
                visiblePoem.displayArtworkStyle.primary.opacity(0.18),
                PoemeryTheme.background,
                PoemeryTheme.background
            ],
            startPoint: .top,
            endPoint: .center
        )
        .ignoresSafeArea()
    }

    private var statusBarText: String {
        "\(shortQueueTitle) · \(readerPositionText)"
    }

    private var visibleAuthor: AuthorResult? {
        library.author(for: visiblePoem)
    }

    private var detailAttributionText: String {
        if visiblePoem.form == script.converted("词") || visiblePoem.tags.contains(script.converted("宋词")) {
            return "\(visiblePoem.author) · \(visiblePoem.form)"
        }
        return "\(visiblePoem.displayArtist) · \(visiblePoem.form)"
    }

    private var shortQueueTitle: String {
        let title = script.converted(currentQueue.title)
        if title.count > 4 {
            return String(title.prefix(4))
        }
        return title
    }

    private var readerPositionText: String {
        guard let currentQueueIndex else {
            return script.converted("正在阅读")
        }
        return script.converted("第 \(currentQueueIndex + 1) 首 / 共 \(currentQueue.poemIDs.count) 首")
    }

    private var relatedPoems: [Poem] {
        library.poems
            .filter { $0.id != visiblePoem.id && !$0.tags.filter(visiblePoem.tags.contains).isEmpty }
            .prefix(4)
            .map { $0 }
    }

    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 20)
            .onEnded { value in
                let horizontalDistance = abs(value.translation.width)
                let verticalDistance = abs(value.translation.height)
                let horizontalVelocity = abs(value.velocity.width)
                let verticalVelocity = abs(value.velocity.height)

                guard horizontalDistance > 48,
                      horizontalDistance > verticalDistance * 1.5,
                      horizontalVelocity > 650,
                      horizontalVelocity > verticalVelocity * 1.5
                else {
                    return
                }

                if value.translation.width < 0 {
                    movePoem(by: 1)
                } else {
                    movePoem(by: -1)
                }
            }
    }

    private func showRelatedPoem(_ poem: Poem, queue: ReadingQueue) {
        session.startReading(poem, in: queue)
        withAnimation(PoemeryTheme.motion) {
            currentPoemID = poem.id
        }
    }

    private func showAuthorPoem(_ poem: Poem, queue: ReadingQueue) {
        session.startReading(poem, in: queue)
        withAnimation(PoemeryTheme.motion) {
            currentPoemID = poem.id
            authorPath = []
        }
    }

    private func movePoem(by offset: Int) {
        guard canMoveInQueue,
              let currentQueueIndex
        else {
            return
        }

        let nextIndex = (currentQueueIndex + offset + currentQueue.poemIDs.count) % currentQueue.poemIDs.count
        guard let poem = library.poem(id: currentQueue.poemIDs[nextIndex]) else {
            return
        }

        session.startReading(poem, in: currentQueue)
        withAnimation(PoemeryTheme.motion) {
            currentPoemID = poem.id
        }
    }

}

private struct PoemShareComposerItem: Identifiable {
    let id = UUID()
    let poem: Poem
}

private struct PoemShareComposer: View {
    let poem: Poem

    @Environment(\.dismiss) private var dismiss
    @Environment(\.chineseScriptPreference) private var script
    @State private var selection = PoemShareSelection.whole
    @State private var backgroundMode = PoemShareBackgroundMode.artworkDefault
    @State private var customBackgroundColor: Color
    @State private var shareSheetItem: PoemShareSheetItem?
    @State private var saveAlert: PoemShareSaveAlert?

    init(poem: Poem) {
        self.poem = poem
        self._customBackgroundColor = State(initialValue: poem.displayArtworkStyle.primary)
    }

    private var selectedLines: [PoemLine] {
        guard case .lines(let lineIDs) = selection else {
            return []
        }
        return poem.lines.filter { lineIDs.contains($0.id) }
    }

    private var backgroundStyle: PoemShareBackgroundStyle {
        switch backgroundMode {
        case .artworkDefault:
            return .artworkDefault
        case .custom:
            return .custom(customBackgroundColor)
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 18) {
                        PoemSharePosterPreview(
                            poem: poem,
                            selectedLines: selectedLines,
                            script: script,
                            backgroundStyle: backgroundStyle
                        )
                            .frame(maxWidth: 420)

                        backgroundSection
                        selectionSection
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 18)
                    .padding(.bottom, 20)
                    .frame(maxWidth: .infinity)
                }
                .scrollIndicators(.hidden)

                shareFooter
            }
            .background(PoemeryTheme.background)
            .navigationTitle(script.converted("分享卡片"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.headline.weight(.semibold))
                    }
                    .accessibilityLabel(script.converted("关闭"))
                }
            }
            .sheet(item: $shareSheetItem) { item in
                PoemShareSheet(item: item)
                    .presentationDetents([.medium, .large])
            }
            .alert(script.converted(saveAlert?.title ?? "分享卡片"), isPresented: saveAlertBinding, presenting: saveAlert) { _ in
                Button(script.converted("好"), role: .cancel) {}
            } message: { alert in
                Text(script.converted(alert.message))
            }
        }
    }

    private var backgroundSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(script.converted("背景"))
                .font(.headline.weight(.semibold))
                .foregroundStyle(PoemeryTheme.primaryText)

            VStack(spacing: 12) {
                Picker(script.converted("背景"), selection: $backgroundMode) {
                    Text(script.converted("作品默认"))
                        .tag(PoemShareBackgroundMode.artworkDefault)
                    Text(script.converted("自定义"))
                        .tag(PoemShareBackgroundMode.custom)
                }
                .pickerStyle(.segmented)

                if backgroundMode == .custom {
                    ColorPicker(
                        script.converted("背景颜色"),
                        selection: $customBackgroundColor,
                        supportsOpacity: false
                    )
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(PoemeryTheme.primaryText)
                }
            }
            .padding(14)
            .background(PoemeryTheme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    private var selectionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(script.converted("内容"))
                .font(.headline.weight(.semibold))
                .foregroundStyle(PoemeryTheme.primaryText)

            VStack(spacing: 0) {
                selectionButton(
                    title: script.converted("全诗"),
                    subtitle: poem.lines.prefix(3).map(\.text).joined(separator: " / "),
                    isSelected: selection == .whole
                ) {
                    selection = .whole
                }

                ForEach(poem.lines) { line in
                    Divider()
                        .padding(.leading, 44)

                    selectionButton(
                        title: line.text,
                        subtitle: nil,
                        isSelected: selection.contains(line.id)
                    ) {
                        toggleLineSelection(line.id)
                    }
                }
            }
            .background(PoemeryTheme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    private func selectionButton(
        title: String,
        subtitle: String?,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(isSelected ? PoemeryTheme.accent : PoemeryTheme.tertiaryText)
                    .frame(width: 24, height: 24)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(PoemeryTheme.chineseFont(size: 18, relativeTo: .body))
                        .foregroundStyle(PoemeryTheme.primaryText)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    if let subtitle, !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(PoemeryTheme.secondaryText)
                            .lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    private var shareFooter: some View {
        VStack(spacing: 0) {
            Divider()

            HStack(spacing: 12) {
                Button {
                    saveSelectedImageToPhotos()
                } label: {
                    Label(script.converted("保存到相册"), systemImage: "square.and.arrow.down")
                        .font(.headline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                }
                .buttonStyle(.bordered)

                Button {
                    exportSelectedImage()
                } label: {
                    Label(script.converted("分享图片"), systemImage: "square.and.arrow.up")
                        .font(.headline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                }
                .buttonStyle(.borderedProminent)
                .tint(PoemeryTheme.accent)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
        }
        .background(.regularMaterial)
    }

    private var saveAlertBinding: Binding<Bool> {
        Binding {
            saveAlert != nil
        } set: { isPresented in
            if !isPresented {
                saveAlert = nil
            }
        }
    }

    @MainActor
    private func exportSelectedImage() {
        guard let image = PoemShareImage.render(
            poem: poem,
            selectedLines: selectedLines,
            script: script,
            backgroundStyle: backgroundStyle
        ) else {
            saveAlert = .exportFailed
            return
        }

        do {
            shareSheetItem = PoemShareSheetItem(
                title: poem.title,
                url: try image.writeTemporaryFile()
            )
        } catch {
            saveAlert = .exportFailed
        }
    }

    @MainActor
    private func saveSelectedImageToPhotos() {
        guard let image = PoemShareImage.render(
            poem: poem,
            selectedLines: selectedLines,
            script: script,
            backgroundStyle: backgroundStyle
        ) else {
            saveAlert = .exportFailed
            return
        }

        Task {
            do {
                try await image.saveToPhotoLibrary()
                await MainActor.run {
                    saveAlert = .saved
                }
            } catch PoemSharePhotoSaveError.denied {
                await MainActor.run {
                    saveAlert = .permissionDenied
                }
            } catch {
                await MainActor.run {
                    saveAlert = .saveFailed
                }
            }
        }
    }

    private func toggleLineSelection(_ lineID: PoemLine.ID) {
        var lineIDs = selection.lineIDs
        if lineIDs.contains(lineID) {
            lineIDs.remove(lineID)
        } else {
            lineIDs.insert(lineID)
        }
        selection = lineIDs.isEmpty ? .whole : .lines(lineIDs)
    }
}

private enum PoemShareSelection: Hashable {
    case whole
    case lines(Set<PoemLine.ID>)

    var lineIDs: Set<PoemLine.ID> {
        guard case .lines(let lineIDs) = self else {
            return []
        }
        return lineIDs
    }

    func contains(_ lineID: PoemLine.ID) -> Bool {
        lineIDs.contains(lineID)
    }
}

private enum PoemShareBackgroundMode: Hashable {
    case artworkDefault
    case custom
}

private enum PoemShareBackgroundStyle {
    case artworkDefault
    case custom(Color)

    func fill(for artworkStyle: ArtworkStyle) -> AnyShapeStyle {
        switch self {
        case .artworkDefault:
            return AnyShapeStyle(
                LinearGradient(
                    colors: [artworkStyle.primary, artworkStyle.secondary, artworkStyle.tertiary],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        case .custom(let color):
            return AnyShapeStyle(color)
        }
    }
}

private enum PoemShareSaveAlert: Identifiable {
    case saved
    case permissionDenied
    case exportFailed
    case saveFailed

    var id: String {
        switch self {
        case .saved: "saved"
        case .permissionDenied: "permissionDenied"
        case .exportFailed: "exportFailed"
        case .saveFailed: "saveFailed"
        }
    }

    var title: String {
        switch self {
        case .saved: "已保存到相册"
        case .permissionDenied: "没有相册权限"
        case .exportFailed: "无法生成图片"
        case .saveFailed: "保存失败"
        }
    }

    var message: String {
        switch self {
        case .saved:
            return "分享卡片已经保存到系统相册。"
        case .permissionDenied:
            return "请在系统设置中允许诗境添加照片。"
        case .exportFailed:
            return "这张分享卡片暂时没有生成成功。"
        case .saveFailed:
            return "请稍后再试，或使用系统分享保存图片。"
        }
    }
}

private struct PoemSharePosterPreview: View {
    let poem: Poem
    let selectedLines: [PoemLine]
    let script: ChineseScriptPreference
    let backgroundStyle: PoemShareBackgroundStyle

    private var aspectRatio: CGFloat {
        PoemSharePoster.posterWidth / PoemSharePoster.posterHeight
    }

    var body: some View {
        GeometryReader { proxy in
            let scale = min(
                proxy.size.width / PoemSharePoster.posterWidth,
                proxy.size.height / PoemSharePoster.posterHeight
            )

            PoemSharePoster(
                poem: poem,
                selectedLines: selectedLines,
                script: script,
                backgroundStyle: backgroundStyle
            )
                .scaleEffect(scale)
                .frame(
                    width: PoemSharePoster.posterWidth * scale,
                    height: PoemSharePoster.posterHeight * scale
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .aspectRatio(aspectRatio, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: .black.opacity(0.16), radius: 22, x: 0, y: 12)
    }
}

private struct PoemShareImage {
    let jpegData: Data
    let fileName: String

    func writeTemporaryFile() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(UUID().uuidString)-\(fileName)")
        try jpegData.write(to: url, options: .atomic)
        return url
    }

    func saveToPhotoLibrary() async throws {
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else {
            throw PoemSharePhotoSaveError.denied
        }

        try await PHPhotoLibrary.shared().performChanges {
            let request = PHAssetCreationRequest.forAsset()
            request.addResource(with: .photo, data: jpegData, options: nil)
        }
    }

    @MainActor
    static func render(
        poem: Poem,
        selectedLines: [PoemLine],
        script: ChineseScriptPreference,
        backgroundStyle: PoemShareBackgroundStyle
    ) -> PoemShareImage? {
        let renderer = ImageRenderer(
            content: PoemSharePoster(
                poem: poem,
                selectedLines: selectedLines,
                script: script,
                backgroundStyle: backgroundStyle
            )
                .frame(width: PoemSharePoster.posterWidth, height: PoemSharePoster.posterHeight)
        )
        renderer.scale = 1

        guard let uiImage = renderer.uiImage,
              let jpegData = uiImage.jpegData(compressionQuality: 0.82)
        else {
            return nil
        }

        return PoemShareImage(
            jpegData: jpegData,
            fileName: imageFileName(poem: poem, selectedLines: selectedLines)
        )
    }

    private static func imageFileName(poem: Poem, selectedLines: [PoemLine]) -> String {
        let selectedText = selectedLines.map(\.text).joined(separator: "-")
        let rawName = selectedText.isEmpty ? poem.title : "\(poem.title)-\(selectedText)"
        let allowedCharacters = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        let sanitized = rawName
            .unicodeScalars
            .map { allowedCharacters.contains($0) ? String($0) : "-" }
            .joined()
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        return "Poemery-\(sanitized.isEmpty ? poem.id : sanitized).jpg"
    }
}

private enum PoemSharePhotoSaveError: Error {
    case denied
}

private struct PoemShareSheetItem: Identifiable {
    let id = UUID()
    let title: String
    let url: URL
}

private struct PoemShareSheet: UIViewControllerRepresentable {
    let item: PoemShareSheetItem

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: [item.url],
            applicationActivities: nil
        )
        controller.setValue(item.title, forKey: "subject")
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

private struct PoemSharePoster: View {
    static let posterWidth: CGFloat = 900
    static let posterHeight: CGFloat = 1200

    let poem: Poem
    let selectedLines: [PoemLine]
    let script: ChineseScriptPreference
    let backgroundStyle: PoemShareBackgroundStyle

    private var style: ArtworkStyle {
        poem.displayArtworkStyle
    }

    private var posterLines: [String] {
        if !selectedLines.isEmpty {
            return selectedLines.map(\.text)
        }

        let maxLineCount = 12
        var lines = poem.lines.prefix(maxLineCount).map(\.text)
        if poem.lines.count > maxLineCount, !lines.isEmpty {
            lines[lines.count - 1] += " ……"
        }
        return lines
    }

    private var poemCharacterCount: Int {
        posterLines.reduce(0) { $0 + $1.count }
    }

    private var longestPosterLineCount: Int {
        max(posterLines.map(\.count).max() ?? 1, 1)
    }

    private var titleFontSize: CGFloat {
        let count = poem.title.count
        if count <= 3 {
            return 78
        }
        if count <= 6 {
            return 68
        }
        if count <= 10 {
            return 58
        }
        return 48
    }

    private var metadataFontSize: CGFloat {
        titleFontSize > 60 ? 31 : 28
    }

    private var poemFontSize: CGFloat {
        if !selectedLines.isEmpty {
            let lineLimitedSize = selectedLines.count > 2 ? CGFloat(64 - min(selectedLines.count, 8) * 3) : 76
            return min(lineLimitedSize, max(34, 620 / CGFloat(longestPosterLineCount)))
        }

        let lineCount = posterLines.count
        let baseSize: CGFloat
        if lineCount <= 4 && poemCharacterCount <= 48 {
            baseSize = 56
        } else if lineCount <= 6 && poemCharacterCount <= 72 {
            baseSize = 48
        } else if lineCount <= 8 && poemCharacterCount <= 112 {
            baseSize = 40
        } else if lineCount <= 10 {
            baseSize = 34
        } else {
            baseSize = 30
        }

        let widthLimitedSize = 600 / CGFloat(longestPosterLineCount)
        return min(baseSize, max(28, widthLimitedSize))
    }

    private var poemLineSpacing: CGFloat {
        if !selectedLines.isEmpty {
            return 24
        }

        if poemFontSize >= 48 {
            return 22
        }
        if poemFontSize >= 40 {
            return 18
        }
        return 14
    }

    private var posterTitleMarkCharacters: [String] {
        let maxCharacterCount = 11
        let characters = poem.title.map(String.init)
        guard characters.count > maxCharacterCount else {
            return characters
        }
        return Array(characters.prefix(maxCharacterCount - 1)) + ["…"]
    }

    private var posterTitleMarkFontSize: CGFloat {
        let count = max(posterTitleMarkCharacters.count, 1)
        return min(116, max(56, 760 / CGFloat(count)))
    }

    private var posterTitleMarkSpacing: CGFloat {
        posterTitleMarkCharacters.count > 7 ? -6 : 2
    }

    var body: some View {
        ZStack {
            posterBackground

            VStack(alignment: .leading, spacing: 0) {
                posterSeal

                Spacer(minLength: 84)

                VStack(alignment: .leading, spacing: 16) {
                    Text(poem.title)
                        .font(PoemeryTheme.chineseFont(size: titleFontSize, relativeTo: .largeTitle).weight(.bold))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .minimumScaleFactor(0.76)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Text("\(poem.displayArtist) · \(poem.form)")
                        .font(.system(size: metadataFontSize, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.82))
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                VStack(alignment: .leading, spacing: poemLineSpacing) {
                    ForEach(posterLines.indices, id: \.self) { index in
                        Text(posterLines[index])
                            .font(PoemeryTheme.chineseFont(size: poemFontSize, relativeTo: .title3))
                            .foregroundStyle(.white.opacity(0.92))
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(.top, 54)

                Spacer(minLength: 132)

                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(script.converted("来自诗境 Poemery"))
                            .font(.system(size: 24, weight: .bold))
                        Text(script.converted("诗意很远，心意很近。"))
                            .font(.system(size: 22, weight: .semibold))
                    }
                    .foregroundStyle(.white.opacity(0.78))

                    Spacer()
                }
            }
            .padding(.leading, 88)
            .padding(.trailing, 174)
            .padding(.top, 84)
            .padding(.bottom, 86)
        }
        .frame(width: Self.posterWidth, height: Self.posterHeight)
        .clipped()
    }

    private var posterBackground: some View {
        Rectangle()
            .fill(backgroundStyle.fill(for: style))
            .overlay {
                LinearGradient(
                    colors: [.white.opacity(0.24), .clear, .black.opacity(0.44)],
                    startPoint: .topTrailing,
                    endPoint: .bottomLeading
                )
            }
            .overlay {
                LinearGradient(
                    colors: [.clear, .white.opacity(0.12), .clear],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .rotationEffect(.degrees(-32))
                .offset(x: 140)
            }
            .overlay(alignment: .topTrailing) {
                posterTitleMark
            }
            .overlay(PaperTexture().opacity(0.18))
    }

    private var posterTitleMark: some View {
        VStack(spacing: posterTitleMarkSpacing) {
            ForEach(posterTitleMarkCharacters.indices, id: \.self) { index in
                Text(posterTitleMarkCharacters[index])
                    .font(PoemeryTheme.chineseFont(size: posterTitleMarkFontSize, relativeTo: .largeTitle).weight(.black))
                    .foregroundStyle(.white.opacity(0.24))
                    .shadow(color: .black.opacity(0.16), radius: 0, x: 1, y: 1)
            }
        }
        .frame(width: 128, alignment: .center)
        .padding(.top, 72)
        .padding(.trailing, 32)
    }

    private var posterSeal: some View {
        VStack(spacing: 5) {
            Text("诗")
            Text("境")
        }
        .font(PoemeryTheme.chineseFont(size: 28, relativeTo: .title2))
        .foregroundStyle(.white.opacity(0.88))
        .frame(width: 76, height: 76)
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(.white.opacity(0.60), lineWidth: 1.5)
        }
    }
}
