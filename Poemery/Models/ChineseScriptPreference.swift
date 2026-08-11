import Foundation
import SwiftUI

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

private struct ChineseScriptPreferenceKey: EnvironmentKey {
    static let defaultValue = ChineseScriptPreference.simplified
}

extension EnvironmentValues {
    var chineseScriptPreference: ChineseScriptPreference {
        get { self[ChineseScriptPreferenceKey.self] }
        set { self[ChineseScriptPreferenceKey.self] = newValue }
    }
}

extension PoemSeedCatalog {
    func converted(to script: ChineseScriptPreference) -> PoemSeedCatalog {
        PoemSeedCatalog(
            poems: poems.map { $0.converted(to: script) },
            collections: collections.map { $0.converted(to: script) },
            categories: categories.map { $0.converted(to: script) },
            authorProfiles: authorProfiles.map { $0.converted(to: script) }
        )
    }
}

extension AuthorProfile {
    func converted(to script: ChineseScriptPreference) -> AuthorProfile {
        AuthorProfile(
            id: id,
            name: script.converted(name),
            dynasty: script.converted(dynasty),
            biography: script.converted(biography),
            lifeYears: lifeYears,
            courtesyNames: courtesyNames.map(script.converted),
            aliases: aliases.map(script.converted),
            nativePlace: nativePlace.map(script.converted),
            sourceName: script.converted(sourceName),
            sourceURL: sourceURL,
            sourceLicense: sourceLicense,
            sourceRevisionID: sourceRevisionID,
            sourceFetchedAt: sourceFetchedAt,
            portrait: portrait
        )
    }
}

extension Poem {
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
            canonicalKey: canonicalKey,
            supplement: supplement?.converted(to: script),
            searchMatch: searchMatch,
            firstLinePreview: script.converted(firstLinePreview)
        )
    }
}

extension PoemSupplement {
    func converted(to script: ChineseScriptPreference) -> PoemSupplement {
        PoemSupplement(
            pronunciations: pronunciations,
            translation: script.converted(translation),
            appreciation: script.converted(appreciation),
            sourceName: script.converted(sourceName),
            sourceURL: sourceURL,
            sourceLicense: sourceLicense
        )
    }
}

extension PoemLine {
    func converted(to script: ChineseScriptPreference) -> PoemLine {
        PoemLine(id: id, order: order, text: script.converted(text))
    }
}

extension PoemAnnotation {
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

extension PoemCollection {
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

extension PoemCategory {
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

extension ArtworkStyle {
    func converted(to script: ChineseScriptPreference) -> ArtworkStyle {
        ArtworkStyle(
            primaryHex: primaryHex,
            secondaryHex: secondaryHex,
            tertiaryHex: tertiaryHex,
            glyph: script.converted(glyph)
        )
    }
}

extension AuthorResult {
    func converted(to script: ChineseScriptPreference) -> AuthorResult {
        AuthorResult(
            id: id,
            name: script.converted(name),
            dynasty: script.converted(dynasty),
            poemCount: poemCount,
            profile: profile?.converted(to: script)
        )
    }
}

extension PoemListItem {
    func converted(to script: ChineseScriptPreference) -> PoemListItem {
        PoemListItem(
            id: id,
            title: script.converted(title),
            author: script.converted(author),
            dynasty: script.converted(dynasty),
            form: script.converted(form),
            artworkStyle: artworkStyle.converted(to: script),
            searchMatch: searchMatch.map {
                SearchMatchSnippet(
                    kind: $0.kind,
                    text: script.converted($0.text),
                    highlightedQuery: script.converted($0.highlightedQuery)
                )
            },
            firstLinePreview: script.converted(firstLinePreview)
        )
    }
}

extension SearchResultsPage {
    func converted(to script: ChineseScriptPreference) -> SearchResultsPage {
        SearchResultsPage(
            poems: poems.map { $0.converted(to: script) },
            authors: authors.map { $0.converted(to: script) },
            collections: collections.map { $0.converted(to: script) },
            totalPoemCount: totalPoemCount,
            nextCursor: nextCursor,
            poemIDs: poemIDs
        )
    }
}

extension PoemLibraryBootstrap {
    func converted(to script: ChineseScriptPreference) -> PoemLibraryBootstrap {
        PoemLibraryBootstrap(
            stats: stats,
            collections: collections.map { $0.converted(to: script) },
            categories: categories.map { $0.converted(to: script) },
            authors: authors.map { $0.converted(to: script) },
            keywords: keywords.map {
                PoemKeyword(id: $0.id, text: script.converted($0.text), count: $0.count, poemIDs: $0.poemIDs)
            },
            dynasties: dynasties.map(script.converted),
            forms: forms.map(script.converted),
            popularPoems: popularPoems.map { $0.converted(to: script) }
        )
    }
}
