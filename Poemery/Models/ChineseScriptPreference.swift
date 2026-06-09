import Foundation

enum ChineseScriptPreference: String, CaseIterable, Identifiable, Sendable {
    case simplified
    case traditional

    static let storageKey = "poemery.display.chineseScript"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .simplified: "简体中文"
        case .traditional: "繁體中文"
        }
    }

    var settingsValue: String {
        switch self {
        case .simplified: "简体"
        case .traditional: "繁體"
        }
    }

    init(rawValue: String?) {
        self = ChineseScriptPreference(rawValue: rawValue ?? "") ?? .simplified
    }

    func converted(_ text: String) -> String {
        ChineseTextConverter.convert(text, to: self)
    }
}

enum ChineseTextConverter {
    static func convert(_ text: String, to script: ChineseScriptPreference) -> String {
        let transformID: String
        switch script {
        case .simplified:
            transformID = "Traditional-Simplified"
        case .traditional:
            transformID = "Simplified-Traditional"
        }

        let mutableText = NSMutableString(string: text)
        guard CFStringTransform(mutableText, nil, transformID as CFString, false) else {
            return text
        }
        return mutableText as String
    }
}

extension PoemSeedCatalog {
    func converted(to script: ChineseScriptPreference) -> PoemSeedCatalog {
        PoemSeedCatalog(
            poems: poems.map { $0.converted(to: script) },
            collections: collections.map { $0.converted(to: script) },
            categories: categories.map { $0.converted(to: script) }
        )
    }
}

private extension Poem {
    func converted(to script: ChineseScriptPreference) -> Poem {
        Poem(
            id: id,
            title: script.converted(title),
            author: script.converted(author),
            dynasty: script.converted(dynasty),
            form: script.converted(form),
            tags: tags.map(script.converted),
            summary: script.converted(summary),
            lines: lines.map { $0.converted(to: script) },
            annotations: annotations.map { $0.converted(to: script) },
            sourceURL: sourceURL,
            artworkStyle: artworkStyle.converted(to: script),
            sourceName: script.converted(sourceName),
            sourceLicense: sourceLicense,
            editorialSummary: script.converted(editorialSummary),
            themes: themes.map(script.converted),
            difficulty: difficulty,
            canonicalKey: canonicalKey
        )
    }
}

private extension PoemLine {
    func converted(to script: ChineseScriptPreference) -> PoemLine {
        PoemLine(id: id, order: order, text: script.converted(text))
    }
}

private extension PoemAnnotation {
    func converted(to script: ChineseScriptPreference) -> PoemAnnotation {
        PoemAnnotation(
            id: id,
            lineID: lineID,
            term: script.converted(term),
            reading: reading,
            summary: script.converted(summary),
            detail: script.converted(detail)
        )
    }
}

private extension PoemCollection {
    func converted(to script: ChineseScriptPreference) -> PoemCollection {
        PoemCollection(
            id: id,
            title: script.converted(title),
            subtitle: script.converted(subtitle),
            kind: kind,
            poemIDs: poemIDs,
            accent: accent.converted(to: script)
        )
    }
}

private extension PoemCategory {
    func converted(to script: ChineseScriptPreference) -> PoemCategory {
        PoemCategory(
            id: id,
            title: script.converted(title),
            subtitle: script.converted(subtitle),
            tag: script.converted(tag),
            artworkStyle: artworkStyle.converted(to: script),
            symbol: symbol
        )
    }
}

private extension ArtworkStyle {
    func converted(to script: ChineseScriptPreference) -> ArtworkStyle {
        ArtworkStyle(
            primaryHex: primaryHex,
            secondaryHex: secondaryHex,
            tertiaryHex: tertiaryHex,
            glyph: script.converted(glyph)
        )
    }
}
