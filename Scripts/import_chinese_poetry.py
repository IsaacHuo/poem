#!/usr/bin/env python3
"""Build Poemery's bundled catalog from chinese-poetry/chinese-poetry."""

from __future__ import annotations

import argparse
import collections
import datetime as dt
import hashlib
import json
import sqlite3
import sys
import urllib.request
from pathlib import Path
from typing import Any


REPOSITORY = "chinese-poetry/chinese-poetry"
REPOSITORY_URL = f"https://github.com/{REPOSITORY}"
COMMIT = "99ebbef7e1345c0985c44b9fd96a3f9e776f117b"
RAW_BASE_URL = f"https://raw.githubusercontent.com/{REPOSITORY}/{COMMIT}"
BLOB_BASE_URL = f"{REPOSITORY_URL}/blob/{COMMIT}"

SOURCES = {
    "tang-300": {
        "path": "%E5%85%A8%E5%94%90%E8%AF%97/%E5%94%90%E8%AF%97%E4%B8%89%E7%99%BE%E9%A6%96.json",
        "label": "唐诗三百首",
        "expected_count": 366,
        "dynasty": "唐",
        "form": "诗",
        "base_tags": ["唐诗", "唐诗三百首"],
        "summary": "来源于 chinese-poetry/chinese-poetry 的《唐诗三百首》数据；此处保留上游原文字形。",
    },
    "song-ci-300": {
        "path": "%E5%AE%8B%E8%AF%8D/%E5%AE%8B%E8%AF%8D%E4%B8%89%E7%99%BE%E9%A6%96.json",
        "label": "宋词三百首",
        "expected_count": 280,
        "dynasty": "宋",
        "form": "词",
        "base_tags": ["宋词", "宋词三百首"],
        "summary": "来源于 chinese-poetry/chinese-poetry 的《宋词三百首》数据；此处保留上游原文字形。",
    },
    "yuanqu": {
        "path": "%E5%85%83%E6%9B%B2/yuanqu.json",
        "label": "元曲",
        "expected_count": 11057,
        "dynasty": "元",
        "form": "曲",
        "base_tags": ["元曲"],
        "summary": "来源于 chinese-poetry/chinese-poetry 的《元曲》数据；此处保留上游原文字形。",
    },
    "lunyu": {
        "path": "%E8%AE%BA%E8%AF%AD/lunyu.json",
        "label": "论语",
        "expected_count": 20,
        "dynasty": "先秦",
        "form": "典籍",
        "author": "孔门弟子",
        "base_tags": ["论语", "儒家", "经典"],
        "summary": "来源于 chinese-poetry/chinese-poetry 的《论语》数据；此处按篇章保留上游原文字形。",
        "format": "chaptered",
    },
    "shijing": {
        "path": "%E8%AF%97%E7%BB%8F/shijing.json",
        "label": "诗经",
        "expected_count": 305,
        "dynasty": "先秦",
        "form": "诗",
        "author": "佚名",
        "base_tags": ["诗经", "先秦诗", "经典"],
        "summary": "来源于 chinese-poetry/chinese-poetry 的《诗经》数据；此处保留上游原文字形。",
        "format": "shijing",
    },
    "daxue": {
        "path": "%E5%9B%9B%E4%B9%A6%E4%BA%94%E7%BB%8F/daxue.json",
        "label": "大学",
        "expected_count": 1,
        "dynasty": "先秦",
        "form": "典籍",
        "author": "曾子门人",
        "base_tags": ["四书五经", "大学", "儒家", "经典"],
        "summary": "来源于 chinese-poetry/chinese-poetry 的《四书五经/大学》数据；此处保留上游原文字形。",
        "format": "chaptered",
    },
    "mengzi": {
        "path": "%E5%9B%9B%E4%B9%A6%E4%BA%94%E7%BB%8F/mengzi.json",
        "label": "孟子",
        "expected_count": 14,
        "dynasty": "先秦",
        "form": "典籍",
        "author": "孟子",
        "base_tags": ["四书五经", "孟子", "儒家", "经典"],
        "summary": "来源于 chinese-poetry/chinese-poetry 的《四书五经/孟子》数据；此处按篇章保留上游原文字形。",
        "format": "chaptered",
    },
    "zhongyong": {
        "path": "%E5%9B%9B%E4%B9%A6%E4%BA%94%E7%BB%8F/zhongyong.json",
        "label": "中庸",
        "expected_count": 1,
        "dynasty": "先秦",
        "form": "典籍",
        "author": "子思",
        "base_tags": ["四书五经", "中庸", "儒家", "经典"],
        "summary": "来源于 chinese-poetry/chinese-poetry 的《四书五经/中庸》数据；此处保留上游原文字形。",
        "format": "chaptered",
    },
}

EXPECTED_SKIPPED_EMPTY_TEXT_COUNT = 2
EXPECTED_TOTAL = sum(source["expected_count"] for source in SOURCES.values()) - EXPECTED_SKIPPED_EMPTY_TEXT_COUNT

TANG_FORMS = [
    "五言绝句",
    "七言绝句",
    "五言律诗",
    "七言律诗",
    "五言古诗",
    "七言古诗",
    "乐府",
]

SOURCE_PALETTES = {
    "tang-300": [
        ("#A33A32", "#E8B96F", "#2B2B34"),
        ("#6F3D2E", "#D7A85E", "#26323A"),
        ("#8C3F4D", "#F2C078", "#2F2A35"),
        ("#315B4F", "#D0B16E", "#243130"),
        ("#7A2E2A", "#D58A62", "#342B2B"),
        ("#4C4E8A", "#C2B6E8", "#25283B"),
        ("#A0572A", "#E2C46E", "#2E3028"),
    ],
    "song-ci-300": [
        ("#2F6F73", "#9CC6B8", "#26323A"),
        ("#395C8A", "#B9C7E6", "#2B2B34"),
        ("#426B55", "#B8C99D", "#2A332A"),
        ("#74486A", "#D3A7BF", "#312734"),
        ("#2F5D8C", "#A8C7D8", "#253242"),
        ("#5B6F47", "#D5C88A", "#2C3328"),
        ("#7C4B53", "#D6A39B", "#30272A"),
    ],
    "yuanqu": [
        ("#8E5B2D", "#D8A15D", "#2E2A26"),
        ("#6B4A7A", "#C9A7D8", "#2D2932"),
        ("#9B4D38", "#D9B083", "#302927"),
        ("#3F6B66", "#C2B47C", "#253433"),
        ("#8C3C5C", "#D89AB1", "#302733"),
        ("#5B4A32", "#C79D60", "#2C2925"),
        ("#3F527D", "#B9B4D6", "#252B3B"),
    ],
    "lunyu": [
        ("#3F5F51", "#D2C488", "#263029"),
        ("#5C5542", "#CDBB78", "#2E2C25"),
        ("#465F72", "#AEC8D6", "#242D35"),
    ],
    "shijing": [
        ("#8B3C63", "#D6A5C2", "#2B2632"),
        ("#3B6B54", "#AFCB9E", "#253228"),
        ("#7A4231", "#D58E70", "#302827"),
        ("#355B72", "#A9D0CA", "#242E36"),
    ],
    "daxue": [
        ("#4F5F38", "#D4C989", "#293025"),
        ("#6F4C35", "#D9A35F", "#2C2925"),
        ("#46588C", "#BFB7E7", "#252A3A"),
    ],
    "mengzi": [
        ("#6F3D2E", "#D7A85E", "#26323A"),
        ("#3C5E8D", "#AEC8E6", "#242C3A"),
        ("#316A74", "#D1C17C", "#243233"),
    ],
    "zhongyong": [
        ("#584B9C", "#B8A7E8", "#252538"),
        ("#2F6658", "#D3B56D", "#232F2D"),
        ("#8C4A39", "#DFB28A", "#302A28"),
    ],
}

SOURCE_FALLBACK_GLYPHS = {
    "tang-300": "诗",
    "song-ci-300": "词",
    "yuanqu": "曲",
    "lunyu": "论",
    "shijing": "经",
    "daxue": "大",
    "mengzi": "孟",
    "zhongyong": "中",
}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--output",
        default="Poemery/PoemsSeed.json",
        help="Catalog output path.",
    )
    parser.add_argument(
        "--notice-output",
        default="Poemery/ChinesePoetryNotice.txt",
        help="Bundled data-source notice output path.",
    )
    parser.add_argument(
        "--sqlite-output",
        default="Poemery/PoemLibrary.sqlite",
        help="Bundled SQLite catalog output path.",
    )
    parser.add_argument(
        "--sqlite-from-catalog",
        help="Write SQLite from an existing PoemsSeed.json without fetching upstream sources.",
    )
    args = parser.parse_args()

    if args.sqlite_from_catalog:
        catalog = json.loads(Path(args.sqlite_from_catalog).read_text(encoding="utf-8"))
        validate_catalog(catalog)
        sqlite_output = Path(args.sqlite_output)
        write_sqlite_catalog(catalog, sqlite_output)
        validate_sqlite_catalog(sqlite_output, catalog)
        print(f"Wrote {sqlite_output}")
        return 0

    catalog, report = build_catalog()
    validate_catalog(catalog)

    output = Path(args.output)
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(
        json.dumps(catalog, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )

    notice_output = Path(args.notice_output)
    notice_output.parent.mkdir(parents=True, exist_ok=True)
    notice_output.write_text(build_notice(report), encoding="utf-8")

    sqlite_output = Path(args.sqlite_output)
    write_sqlite_catalog(catalog, sqlite_output)
    validate_sqlite_catalog(sqlite_output, catalog)

    print(f"Wrote {output} ({len(catalog['poems'])} poems)")
    print(f"Wrote {notice_output}")
    print(f"Wrote {sqlite_output}")
    for source_id, count in report["source_counts"].items():
        print(f"{source_id}: {count}")
    if report["duplicate_base_ids"]:
        print(f"Duplicate content hashes with stable suffixes: {report['duplicate_base_ids']}")
    if report["skipped_items"]:
        print("Skipped empty-text items:")
        for item in report["skipped_items"]:
            print(f"- {item}")

    return 0


def build_catalog() -> tuple[dict[str, Any], dict[str, Any]]:
    poems: list[dict[str, Any]] = []
    source_counts: dict[str, int] = {}
    skipped_items: list[str] = []
    base_id_counts: collections.Counter[str] = collections.Counter()

    for source_id, config in SOURCES.items():
        items = fetch_json(config["path"])
        if not isinstance(items, list) and int(config["expected_count"]) == 1:
            items = [items]
        if not isinstance(items, list):
            raise ValueError(f"{source_id} did not return a JSON array")
        expected_count = int(config["expected_count"])
        if len(items) != expected_count:
            raise ValueError(f"{source_id} expected {expected_count} items, got {len(items)}")

        source_counts[source_id] = len(items)
        for item in items:
            poem = convert_item(source_id, config, item, base_id_counts)
            if poem is None:
                skipped_items.append(f"{source_id}/{skipped_item_label(item)}")
                continue
            poems.append(poem)

    if len(skipped_items) != EXPECTED_SKIPPED_EMPTY_TEXT_COUNT:
        raise ValueError(f"Expected {EXPECTED_SKIPPED_EMPTY_TEXT_COUNT} skipped empty-text items, got {len(skipped_items)}: {skipped_items}")

    collections_data = build_collections(poems)
    categories = build_categories(poems)
    catalog = {
        "poems": poems,
        "collections": collections_data,
        "categories": categories,
    }
    report = {
        "source_counts": source_counts,
        "skipped_items": skipped_items,
        "duplicate_base_ids": sum(1 for count in base_id_counts.values() if count > 1),
    }
    return catalog, report


def fetch_json(encoded_path: str) -> Any:
    with urllib.request.urlopen(f"{RAW_BASE_URL}/{encoded_path}", timeout=60) as response:
        return json.loads(response.read().decode("utf-8"))


def fetch_text(encoded_path: str) -> str:
    with urllib.request.urlopen(f"{RAW_BASE_URL}/{encoded_path}", timeout=60) as response:
        return response.read().decode("utf-8")


def convert_item(
    source_id: str,
    config: dict[str, Any],
    item: dict[str, Any],
    base_id_counts: collections.Counter[str],
) -> dict[str, Any] | None:
    source_format = config.get("format", "poem")

    if source_format == "chaptered":
        author = str(config.get("author") or "佚名")
        title = clean_text(item.get("chapter")) or str(config["label"])
        paragraphs = cleaned_paragraphs(item.get("paragraphs", []))
    elif source_format == "shijing":
        author = str(config.get("author") or "佚名")
        title = clean_text(item.get("title")) or "无题"
        paragraphs = cleaned_paragraphs(item.get("content", []))
    else:
        author = clean_text(item.get("author")) or str(config.get("author") or "佚名")
        title = clean_text(item.get("title")) or clean_text(item.get("rhythmic")) or "无题"
        paragraphs = cleaned_paragraphs(item.get("paragraphs", []))

    if not paragraphs:
        title, paragraphs = repair_empty_paragraphs(source_id, title)
    if not paragraphs:
        return None

    base_id = stable_base_id(source_id, author, title, paragraphs)
    base_id_counts[base_id] += 1
    occurrence = base_id_counts[base_id]
    poem_id = base_id if occurrence == 1 else f"{base_id}-{occurrence}"

    tags = merged_tags(config["base_tags"], item.get("tags", []), shijing_tags(item) if source_format == "shijing" else [])
    if source_id == "song-ci-300":
        rhythmic = clean_text(item.get("rhythmic"))
        if rhythmic:
            tags = merged_tags(tags, [rhythmic])

    form = infer_form(source_id, tags, str(config["form"]))
    if form not in tags:
        tags = merged_tags(tags, [form])

    return {
        "id": poem_id,
        "title": title,
        "author": author,
        "dynasty": str(config["dynasty"]),
        "form": form,
        "tags": tags,
        "summary": str(config["summary"]),
        "themes": themes_for_poem(source_id, author, title, form, tags, paragraphs),
        "difficulty": difficulty_for_poem(form, paragraphs),
        "sourceURL": f"{BLOB_BASE_URL}/{config['path']}",
        "artworkStyle": artwork_style(source_id, poem_id, title),
        "lines": [
            {
                "id": f"{poem_id}-{index + 1}",
                "order": index,
                "text": text,
            }
            for index, text in enumerate(paragraphs)
        ],
        "annotations": [],
    }


def skipped_item_label(item: dict[str, Any]) -> str:
    return (
        clean_text(item.get("author"))
        or clean_text(item.get("chapter"))
        or clean_text(item.get("title"))
        or clean_text(item.get("rhythmic"))
        or "无题"
    )


def clean_text(value: Any) -> str:
    return str(value or "").strip()


def cleaned_paragraphs(values: Any) -> list[str]:
    return [paragraph for paragraph in [clean_text(value) for value in values or []] if paragraph]


def shijing_tags(item: dict[str, Any]) -> list[str]:
    tags = [
        clean_text(item.get("chapter")),
        clean_text(item.get("section")),
    ]
    if clean_text(item.get("chapter")).endswith("颂"):
        tags.append("颂")
    return tags


def repair_empty_paragraphs(source_id: str, title: str) -> tuple[str, list[str]]:
    if source_id == "yuanqu" and "・" in title:
        repaired_title, repaired_text = title.split("・", 1)
        if clean_text(repaired_text):
            return clean_text(repaired_title) or "无题", [clean_text(repaired_text)]
    return title, []


def stable_base_id(source_id: str, author: str, title: str, paragraphs: list[str]) -> str:
    payload = json.dumps(
        {
            "source": source_id,
            "author": author,
            "title": title,
            "paragraphs": paragraphs,
        },
        ensure_ascii=False,
        sort_keys=True,
        separators=(",", ":"),
    )
    digest = hashlib.sha256(payload.encode("utf-8")).hexdigest()[:16]
    return f"cp-{source_id}-{digest}"


def merged_tags(*tag_groups: Any) -> list[str]:
    tags: list[str] = []
    for group in tag_groups:
        if isinstance(group, str):
            group = [group]
        for tag in group or []:
            clean_tag = clean_text(tag)
            if clean_tag and clean_tag not in tags:
                tags.append(clean_tag)
    return tags


def infer_form(source_id: str, tags: list[str], fallback: str) -> str:
    if source_id == "tang-300":
        for form in TANG_FORMS:
            if form in tags:
                return form
    return fallback


def themes_for_poem(source_id: str, author: str, title: str, form: str, tags: list[str], paragraphs: list[str]) -> list[str]:
    text = "".join([title, author, form, *tags, *paragraphs])
    themes = [SOURCES[source_id]["dynasty"], form]
    theme_keywords = [
        ("思乡", ["乡", "故园", "故乡", "归", "客", "家"]),
        ("送别", ["送", "别", "离", "渡", "长亭"]),
        ("山水", ["山", "水", "江", "河", "湖", "溪", "泉"]),
        ("月夜", ["月", "夜", "霜", "灯", "星"]),
        ("边塞", ["塞", "关", "胡", "羌", "戍", "沙场"]),
        ("春景", ["春", "花", "柳", "莺", "燕"]),
        ("秋思", ["秋", "落叶", "雁", "寒"]),
        ("怀古", ["古", "台", "宫", "赤壁", "兴亡"]),
        ("爱国", ["国", "山河", "中原", "北定", "功名"]),
        ("哲理", ["道", "理", "心", "梦", "身", "世"]),
        ("抒情", ["情", "愁", "泪", "恨", "思"]),
    ]
    for theme, keywords in theme_keywords:
        if any(keyword in text for keyword in keywords):
            themes.append(theme)
    themes.extend(tags[:4])
    return dedupe(themes)[:8]


def difficulty_for_poem(form: str, paragraphs: list[str]) -> int:
    character_count = sum(len(paragraph) for paragraph in paragraphs)
    if form == "曲" or character_count > 180:
        return 4
    if form == "词" or character_count > 96:
        return 3
    if character_count < 48:
        return 1
    return 2


def dedupe(values: list[str]) -> list[str]:
    result: list[str] = []
    for value in values:
        clean_value = clean_text(value)
        if clean_value and clean_value not in result:
            result.append(clean_value)
    return result


def artwork_style(source_id: str, poem_id: str, title: str) -> dict[str, str]:
    palettes = SOURCE_PALETTES[source_id]
    palette = palettes[int(hashlib.sha256(poem_id.encode("utf-8")).hexdigest()[:2], 16) % len(palettes)]
    return {
        "primaryHex": palette[0],
        "secondaryHex": palette[1],
        "tertiaryHex": palette[2],
        "glyph": first_cjk(title) or SOURCE_FALLBACK_GLYPHS[source_id],
    }


def first_cjk(value: str) -> str | None:
    for character in value:
        if "\u4e00" <= character <= "\u9fff":
            return character
    return None


def build_collections(poems: list[dict[str, Any]]) -> list[dict[str, Any]]:
    by_tag = poems_by_tag(poems)
    by_author = poems_by_author(poems)
    by_dynasty = poems_by_field(poems, "dynasty")
    by_form = poems_by_field(poems, "form")
    by_theme = poems_by_theme(poems)
    collections_data = [
        make_collection(
            "cp-collection-tang-300",
            "唐诗三百首",
            f"{len(by_tag['唐诗三百首'])} 首唐诗精选",
            "featured",
            by_tag["唐诗三百首"],
            style("#A33A32", "#E8B96F", "#2B2B34", "唐"),
        ),
        make_collection(
            "cp-collection-song-ci-300",
            "宋词三百首",
            f"{len(by_tag['宋词三百首'])} 首宋词精选",
            "featured",
            by_tag["宋词三百首"],
            style("#2F6F73", "#9CC6B8", "#26323A", "宋"),
        ),
        make_collection(
            "cp-collection-yuanqu",
            "元曲",
            f"{len(by_tag['元曲'])} 条元曲作品",
            "chart",
            by_tag["元曲"],
            style("#8E5B2D", "#D8A15D", "#2E2A26", "曲"),
        ),
    ]

    for tag, title, subtitle, accent in [
        ("论语", "论语", "20 篇儒家语录", style("#3F5F51", "#D2C488", "#263029", "论")),
        ("诗经", "诗经", "305 首先秦诗歌", style("#8B3C63", "#D6A5C2", "#2B2632", "经")),
        ("四书五经", "四书五经", "大学、中庸与孟子", style("#4F5F38", "#D4C989", "#293025", "书")),
    ]:
        source_poems = by_tag.get(tag, [])
        if source_poems:
            collections_data.append(
                make_collection(
                    f"cp-collection-source-{slug(tag)}",
                    title,
                    subtitle,
                    "featured",
                    source_poems,
                    accent,
                )
            )

    for tag, title, glyph, accent in [
        ("国风", "诗经·国风", "风", style("#7E365A", "#D99EB3", "#2C2530", "风")),
        ("小雅", "诗经·小雅", "雅", style("#355B72", "#A9D0CA", "#242E36", "雅")),
        ("大雅", "诗经·大雅", "雅", style("#46588C", "#BFB7E7", "#252A3A", "雅")),
        ("颂", "诗经·颂", "颂", style("#8C4A39", "#DFB28A", "#302A28", "颂")),
        ("孟子", "孟子", "孟", style("#6F3D2E", "#D7A85E", "#26323A", "孟")),
    ]:
        source_poems = by_tag.get(tag, [])
        if source_poems:
            collections_data.append(
                make_collection(
                    f"cp-collection-classic-{slug(tag)}",
                    title,
                    f"{len(source_poems)} 篇/首",
                    "mood",
                    source_poems,
                    accent,
                )
            )

    for author, accent in [
        ("李白", style("#A33A32", "#F2C078", "#2B2B34", "李")),
        ("杜甫", style("#6F3D2E", "#D7A85E", "#26323A", "杜")),
        ("苏轼", style("#395C8A", "#B9C7E6", "#2B2B34", "苏")),
        ("关汉卿", style("#8E5B2D", "#D8A15D", "#2E2A26", "关")),
    ]:
        author_poems = by_author.get(author, [])
        if author_poems:
            collections_data.append(
                make_collection(
                    f"cp-collection-author-{slug(author)}",
                    f"{author}精选",
                    f"{len(author_poems)} 首作品",
                    "author",
                    author_poems,
                    accent,
                )
            )

    for dynasty, accent in [
        ("唐", style("#A33A32", "#E8B96F", "#2B2B34", "唐")),
        ("宋", style("#2F6F73", "#9CC6B8", "#26323A", "宋")),
        ("元", style("#8E5B2D", "#D8A15D", "#2E2A26", "元")),
    ]:
        dynasty_poems = by_dynasty.get(dynasty, [])
        if dynasty_poems:
            collections_data.append(
                make_collection(
                    f"cp-collection-era-{slug(dynasty)}",
                    f"{dynasty}代书架",
                    f"{len(dynasty_poems)} 首/条作品",
                    "era",
                    dynasty_poems,
                    accent,
                )
            )

    for form, accent in [
        ("五言绝句", style("#355B72", "#A9D0CA", "#242E36", "五")),
        ("七言律诗", style("#584B9C", "#B8A7E8", "#252538", "律")),
        ("词", style("#2F6F73", "#9CC6B8", "#26323A", "词")),
        ("曲", style("#8E5B2D", "#D8A15D", "#2E2A26", "曲")),
    ]:
        form_poems = by_form.get(form, [])
        if form_poems:
            collections_data.append(
                make_collection(
                    f"cp-collection-form-{slug(form)}",
                    form,
                    f"{len(form_poems)} 首/条作品",
                    "mood",
                    form_poems,
                    accent,
                )
            )

    for theme, accent in [
        ("思乡", style("#355B72", "#A9D0CA", "#242E36", "乡")),
        ("月夜", style("#3C5E8D", "#AEC8E6", "#242C3A", "月")),
        ("送别", style("#7E365A", "#D99EB3", "#2C2530", "别")),
        ("山水", style("#2F6658", "#D3B56D", "#232F2D", "山")),
    ]:
        theme_poems = by_theme.get(theme, [])
        if theme_poems:
            collections_data.append(
                make_collection(
                    f"cp-collection-theme-{slug(theme)}",
                    f"{theme}诗词",
                    f"{len(theme_poems)} 首相关作品",
                    "mood",
                    theme_poems,
                    accent,
                )
            )

    return collections_data


def build_categories(poems: list[dict[str, Any]]) -> list[dict[str, Any]]:
    candidates = [
        ("cp-category-tang", "唐诗", "唐诗三百首", "唐诗", "book.closed.fill", style("#A33A32", "#E8B96F", "#2B2B34", "唐")),
        ("cp-category-song-ci", "宋词", "宋词三百首", "宋词", "music.note", style("#2F6F73", "#9CC6B8", "#26323A", "宋")),
        ("cp-category-yuanqu", "元曲", "杂剧与散曲", "元曲", "theatermasks.fill", style("#8E5B2D", "#D8A15D", "#2E2A26", "曲")),
        ("cp-category-lunyu", "论语", "孔门语录", "论语", "quote.bubble.fill", style("#3F5F51", "#D2C488", "#263029", "论")),
        ("cp-category-shijing", "诗经", "风雅颂", "诗经", "scroll.fill", style("#8B3C63", "#D6A5C2", "#2B2632", "经")),
        ("cp-category-classics", "四书五经", "大学中庸孟子", "四书五经", "books.vertical.fill", style("#4F5F38", "#D4C989", "#293025", "书")),
        ("cp-category-moon", "月夜", "月色与夜读", "月夜", "moon.stars.fill", style("#3C5E8D", "#AEC8E6", "#242C3A", "月")),
        ("cp-category-homesick", "思乡", "旅人与故园", "思乡", "house.fill", style("#355B72", "#A9D0CA", "#242E36", "乡")),
        ("cp-category-landscape", "山水", "山川与江河", "山水", "mountain.2.fill", style("#2F6658", "#D3B56D", "#232F2D", "山")),
        ("cp-category-li-bai", "李白", "唐代诗人", "李白", "person.fill", style("#A33A32", "#F2C078", "#2B2B34", "李")),
        ("cp-category-du-fu", "杜甫", "唐代诗人", "杜甫", "person.fill", style("#6F3D2E", "#D7A85E", "#26323A", "杜")),
        ("cp-category-su-shi", "苏轼", "宋代词人", "苏轼", "person.fill", style("#395C8A", "#B9C7E6", "#2B2B34", "苏")),
        ("cp-category-guan-hanqing", "关汉卿", "元曲作家", "关汉卿", "person.fill", style("#8E5B2D", "#D8A15D", "#2E2A26", "关")),
    ]
    categories = []
    for category in candidates:
        category_id, title, subtitle, tag, symbol, category_style = category
        if any(tag in poem["tags"] or tag in poem.get("themes", []) or tag == poem["dynasty"] or tag == poem["form"] or tag == poem["author"] for poem in poems):
            categories.append(
                {
                    "id": category_id,
                    "title": title,
                    "subtitle": subtitle,
                    "tag": tag,
                    "artworkStyle": category_style,
                    "symbol": symbol,
                }
            )
    return categories


def poems_by_tag(poems: list[dict[str, Any]]) -> dict[str, list[str]]:
    grouped: dict[str, list[str]] = collections.defaultdict(list)
    for poem in poems:
        for tag in poem["tags"]:
            grouped[tag].append(poem["id"])
    return grouped


def poems_by_author(poems: list[dict[str, Any]]) -> dict[str, list[str]]:
    grouped: dict[str, list[str]] = collections.defaultdict(list)
    for poem in poems:
        grouped[poem["author"]].append(poem["id"])
    return grouped


def poems_by_field(poems: list[dict[str, Any]], field: str) -> dict[str, list[str]]:
    grouped: dict[str, list[str]] = collections.defaultdict(list)
    for poem in poems:
        grouped[clean_text(poem.get(field))].append(poem["id"])
    return grouped


def poems_by_theme(poems: list[dict[str, Any]]) -> dict[str, list[str]]:
    grouped: dict[str, list[str]] = collections.defaultdict(list)
    for poem in poems:
        for theme in poem.get("themes", []):
            grouped[theme].append(poem["id"])
    return grouped


def make_collection(
    collection_id: str,
    title: str,
    subtitle: str,
    kind: str,
    poem_ids: list[str],
    accent: dict[str, str],
) -> dict[str, Any]:
    return {
        "id": collection_id,
        "title": title,
        "subtitle": subtitle,
        "kind": kind,
        "poemIDs": poem_ids,
        "accent": accent,
    }


def style(primary: str, secondary: str, tertiary: str, glyph: str) -> dict[str, str]:
    return {
        "primaryHex": primary,
        "secondaryHex": secondary,
        "tertiaryHex": tertiary,
        "glyph": glyph,
    }


def slug(value: str) -> str:
    return hashlib.sha256(value.encode("utf-8")).hexdigest()[:8]


def validate_catalog(catalog: dict[str, Any]) -> None:
    poems = catalog["poems"]
    if len(poems) != EXPECTED_TOTAL:
        raise ValueError(f"Expected {EXPECTED_TOTAL} poems, got {len(poems)}")

    poem_ids = [poem["id"] for poem in poems]
    duplicate_ids = [poem_id for poem_id, count in collections.Counter(poem_ids).items() if count > 1]
    if duplicate_ids:
        raise ValueError(f"Duplicate poem ids: {duplicate_ids[:5]}")

    poem_id_set = set(poem_ids)
    for poem in poems:
        required_fields = [
            "id",
            "title",
            "author",
            "dynasty",
            "form",
            "tags",
            "summary",
            "lines",
            "annotations",
            "artworkStyle",
            "themes",
            "difficulty",
        ]
        missing = [field for field in required_fields if field not in poem]
        if missing:
            raise ValueError(f"{poem.get('id', '<unknown>')} missing {missing}")
        if not poem["title"] or not poem["author"] or not poem["lines"]:
            raise ValueError(f"{poem['id']} has incomplete title, author, or lines")
        if not poem["themes"] or not (1 <= int(poem["difficulty"]) <= 5):
            raise ValueError(f"{poem['id']} has invalid themes or difficulty")
        orders = [line["order"] for line in poem["lines"]]
        if orders != list(range(len(orders))):
            raise ValueError(f"{poem['id']} line orders are not contiguous")

    for collection_data in catalog["collections"]:
        invalid_ids = [poem_id for poem_id in collection_data["poemIDs"] if poem_id not in poem_id_set]
        if invalid_ids:
            raise ValueError(f"{collection_data['id']} references missing poems: {invalid_ids[:5]}")

    for category in catalog["categories"]:
        tag = category["tag"]
        if not any(tag in poem["tags"] or tag in poem.get("themes", []) or tag == poem["dynasty"] or tag == poem["form"] or tag == poem["author"] for poem in poems):
            raise ValueError(f"{category['id']} does not match any poems")


def write_sqlite_catalog(catalog: dict[str, Any], output: Path) -> None:
    output.parent.mkdir(parents=True, exist_ok=True)
    if output.exists():
        output.unlink()

    with sqlite3.connect(output) as connection:
        connection.execute("PRAGMA foreign_keys = ON")
        create_sqlite_schema(connection)
        insert_sqlite_catalog(connection, catalog)
        connection.execute("PRAGMA user_version = 1")
        connection.commit()


def create_sqlite_schema(connection: sqlite3.Connection) -> None:
    connection.executescript(
        """
        CREATE TABLE metadata (
            key TEXT PRIMARY KEY NOT NULL,
            value TEXT NOT NULL
        ) WITHOUT ROWID;

        CREATE TABLE poems (
            id TEXT PRIMARY KEY NOT NULL,
            title TEXT NOT NULL,
            author TEXT NOT NULL,
            dynasty TEXT NOT NULL,
            form TEXT NOT NULL,
            summary TEXT NOT NULL,
            source_url TEXT,
            source_name TEXT NOT NULL,
            source_license TEXT NOT NULL,
            editorial_summary TEXT,
            difficulty INTEGER NOT NULL,
            canonical_key TEXT,
            artwork_primary_hex TEXT NOT NULL,
            artwork_secondary_hex TEXT NOT NULL,
            artwork_tertiary_hex TEXT NOT NULL,
            artwork_glyph TEXT NOT NULL,
            sort_order INTEGER NOT NULL
        ) WITHOUT ROWID;

        CREATE TABLE poem_lines (
            poem_id TEXT NOT NULL REFERENCES poems(id) ON DELETE CASCADE,
            line_id TEXT NOT NULL,
            line_order INTEGER NOT NULL,
            text TEXT NOT NULL,
            PRIMARY KEY (poem_id, line_order)
        ) WITHOUT ROWID;

        CREATE TABLE poem_annotations (
            poem_id TEXT NOT NULL REFERENCES poems(id) ON DELETE CASCADE,
            annotation_id TEXT NOT NULL,
            line_id TEXT NOT NULL,
            term TEXT NOT NULL,
            reading TEXT NOT NULL,
            summary TEXT NOT NULL,
            detail TEXT NOT NULL,
            annotation_order INTEGER NOT NULL,
            PRIMARY KEY (poem_id, annotation_id)
        ) WITHOUT ROWID;

        CREATE TABLE poem_tags (
            poem_id TEXT NOT NULL REFERENCES poems(id) ON DELETE CASCADE,
            tag TEXT NOT NULL,
            tag_order INTEGER NOT NULL,
            PRIMARY KEY (poem_id, tag_order)
        ) WITHOUT ROWID;

        CREATE TABLE poem_themes (
            poem_id TEXT NOT NULL REFERENCES poems(id) ON DELETE CASCADE,
            theme TEXT NOT NULL,
            theme_order INTEGER NOT NULL,
            PRIMARY KEY (poem_id, theme_order)
        ) WITHOUT ROWID;

        CREATE TABLE collections (
            id TEXT PRIMARY KEY NOT NULL,
            title TEXT NOT NULL,
            subtitle TEXT NOT NULL,
            kind TEXT NOT NULL,
            accent_primary_hex TEXT NOT NULL,
            accent_secondary_hex TEXT NOT NULL,
            accent_tertiary_hex TEXT NOT NULL,
            accent_glyph TEXT NOT NULL,
            sort_order INTEGER NOT NULL
        ) WITHOUT ROWID;

        CREATE TABLE collection_poems (
            collection_id TEXT NOT NULL REFERENCES collections(id) ON DELETE CASCADE,
            poem_id TEXT NOT NULL REFERENCES poems(id) ON DELETE CASCADE,
            poem_order INTEGER NOT NULL,
            PRIMARY KEY (collection_id, poem_order)
        ) WITHOUT ROWID;

        CREATE TABLE categories (
            id TEXT PRIMARY KEY NOT NULL,
            title TEXT NOT NULL,
            subtitle TEXT NOT NULL,
            tag TEXT NOT NULL,
            symbol TEXT NOT NULL,
            artwork_primary_hex TEXT NOT NULL,
            artwork_secondary_hex TEXT NOT NULL,
            artwork_tertiary_hex TEXT NOT NULL,
            artwork_glyph TEXT NOT NULL,
            sort_order INTEGER NOT NULL
        ) WITHOUT ROWID;

        CREATE TABLE authors (
            id TEXT PRIMARY KEY NOT NULL,
            name TEXT NOT NULL,
            dynasty TEXT NOT NULL,
            poem_count INTEGER NOT NULL,
            sort_order INTEGER NOT NULL
        ) WITHOUT ROWID;

        CREATE TABLE author_poems (
            author_id TEXT NOT NULL REFERENCES authors(id) ON DELETE CASCADE,
            poem_id TEXT NOT NULL REFERENCES poems(id) ON DELETE CASCADE,
            poem_order INTEGER NOT NULL,
            PRIMARY KEY (author_id, poem_order)
        ) WITHOUT ROWID;

        CREATE TABLE search_grams (
            gram TEXT PRIMARY KEY NOT NULL,
            poem_offsets BLOB NOT NULL
        ) WITHOUT ROWID;

        CREATE INDEX idx_poem_tags_tag ON poem_tags(tag);
        CREATE INDEX idx_poem_themes_theme ON poem_themes(theme);
        CREATE INDEX idx_collection_poems_poem_id ON collection_poems(poem_id);
        CREATE INDEX idx_author_poems_poem_id ON author_poems(poem_id);
        """
    )


def insert_sqlite_catalog(connection: sqlite3.Connection, catalog: dict[str, Any]) -> None:
    generated_at = dt.datetime.now(dt.timezone.utc).replace(microsecond=0).isoformat()
    connection.executemany(
        "INSERT INTO metadata(key, value) VALUES (?, ?)",
        [
            ("schema_version", "1"),
            ("repository", REPOSITORY),
            ("repository_url", REPOSITORY_URL),
            ("commit", COMMIT),
            ("generated_at", generated_at),
            ("poem_count", str(len(catalog["poems"]))),
        ],
    )

    gram_postings: dict[str, list[int]] = collections.defaultdict(list)

    for sort_order, poem in enumerate(catalog["poems"]):
        artwork = poem["artworkStyle"]
        connection.execute(
            """
            INSERT INTO poems(
                id, title, author, dynasty, form, summary, source_url, source_name,
                source_license, editorial_summary, difficulty, canonical_key,
                artwork_primary_hex, artwork_secondary_hex, artwork_tertiary_hex,
                artwork_glyph, sort_order
            )
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            (
                poem["id"],
                poem["title"],
                poem["author"],
                poem["dynasty"],
                poem["form"],
                poem["summary"],
                poem.get("sourceURL"),
                poem.get("sourceName", ""),
                poem.get("sourceLicense", "MIT"),
                poem.get("editorialSummary"),
                int(poem.get("difficulty", 2)),
                poem.get("canonicalKey"),
                artwork["primaryHex"],
                artwork["secondaryHex"],
                artwork["tertiaryHex"],
                artwork["glyph"],
                sort_order,
            ),
        )
        connection.executemany(
            "INSERT INTO poem_lines(poem_id, line_id, line_order, text) VALUES (?, ?, ?, ?)",
            [
                (poem["id"], line["id"], int(line["order"]), line["text"])
                for line in poem["lines"]
            ],
        )
        connection.executemany(
            """
            INSERT INTO poem_annotations(
                poem_id, annotation_id, line_id, term, reading, summary, detail, annotation_order
            )
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            """,
            [
                (
                    poem["id"],
                    annotation["id"],
                    annotation["lineID"],
                    annotation["term"],
                    annotation["reading"],
                    annotation["summary"],
                    annotation["detail"],
                    index,
                )
                for index, annotation in enumerate(poem.get("annotations", []))
            ],
        )
        connection.executemany(
            "INSERT INTO poem_tags(poem_id, tag, tag_order) VALUES (?, ?, ?)",
            [(poem["id"], tag, index) for index, tag in enumerate(poem["tags"])],
        )
        connection.executemany(
            "INSERT INTO poem_themes(poem_id, theme, theme_order) VALUES (?, ?, ?)",
            [(poem["id"], theme, index) for index, theme in enumerate(poem.get("themes", []))],
        )
        for gram in search_grams_for_poem(poem):
            gram_postings[gram].append(sort_order)

    connection.executemany(
        "INSERT INTO search_grams(gram, poem_offsets) VALUES (?, ?)",
        [
            (gram, sqlite3.Binary(encode_varint_postings(postings)))
            for gram, postings in sorted(gram_postings.items())
        ],
    )

    for sort_order, collection_data in enumerate(catalog["collections"]):
        accent = collection_data["accent"]
        connection.execute(
            """
            INSERT INTO collections(
                id, title, subtitle, kind, accent_primary_hex, accent_secondary_hex,
                accent_tertiary_hex, accent_glyph, sort_order
            )
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            (
                collection_data["id"],
                collection_data["title"],
                collection_data["subtitle"],
                collection_data["kind"],
                accent["primaryHex"],
                accent["secondaryHex"],
                accent["tertiaryHex"],
                accent["glyph"],
                sort_order,
            ),
        )
        connection.executemany(
            "INSERT INTO collection_poems(collection_id, poem_id, poem_order) VALUES (?, ?, ?)",
            [
                (collection_data["id"], poem_id, index)
                for index, poem_id in enumerate(collection_data["poemIDs"])
            ],
        )

    for sort_order, category in enumerate(catalog["categories"]):
        artwork = category["artworkStyle"]
        connection.execute(
            """
            INSERT INTO categories(
                id, title, subtitle, tag, symbol, artwork_primary_hex,
                artwork_secondary_hex, artwork_tertiary_hex, artwork_glyph, sort_order
            )
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            (
                category["id"],
                category["title"],
                category["subtitle"],
                category["tag"],
                category["symbol"],
                artwork["primaryHex"],
                artwork["secondaryHex"],
                artwork["tertiaryHex"],
                artwork["glyph"],
                sort_order,
            ),
        )

    for sort_order, author in enumerate(sqlite_authors(catalog["poems"])):
        connection.execute(
            "INSERT INTO authors(id, name, dynasty, poem_count, sort_order) VALUES (?, ?, ?, ?, ?)",
            (author["id"], author["name"], author["dynasty"], len(author["poemIDs"]), sort_order),
        )
        connection.executemany(
            "INSERT INTO author_poems(author_id, poem_id, poem_order) VALUES (?, ?, ?)",
            [
                (author["id"], poem_id, index)
                for index, poem_id in enumerate(author["poemIDs"])
            ],
        )


def sqlite_authors(poems: list[dict[str, Any]]) -> list[dict[str, Any]]:
    authors: collections.OrderedDict[str, dict[str, Any]] = collections.OrderedDict()
    for poem in poems:
        key = f"{poem['dynasty']}|{poem['author']}"
        author = authors.setdefault(
            key,
            {
                "id": f"cp-author-{slug(key)}",
                "name": poem["author"],
                "dynasty": poem["dynasty"],
                "poemIDs": [],
            },
        )
        author["poemIDs"].append(poem["id"])
    return list(authors.values())


def search_grams_for_poem(poem: dict[str, Any]) -> set[str]:
    text = " ".join(
        [
            poem["title"],
            poem["author"],
            poem["dynasty"],
            poem["form"],
            " ".join(poem["tags"]),
            " ".join(poem.get("themes", [])),
            poem.get("sourceName", ""),
            poem.get("sourceLicense", "MIT"),
            poem.get("canonicalKey", ""),
            " ".join(line["text"] for line in poem["lines"]),
        ]
    )
    characters = [character for character in text.lower() if not character.isspace()]
    grams = set(characters)
    grams.update(
        characters[index] + characters[index + 1]
        for index in range(max(0, len(characters) - 1))
    )
    return {gram for gram in grams if gram}


def encode_varint_postings(postings: list[int]) -> bytes:
    encoded = bytearray()
    previous = 0
    for posting in sorted(postings):
        delta = posting - previous
        previous = posting
        while delta >= 0x80:
            encoded.append((delta & 0x7F) | 0x80)
            delta >>= 7
        encoded.append(delta)
    return bytes(encoded)


def validate_sqlite_catalog(output: Path, catalog: dict[str, Any]) -> None:
    with sqlite3.connect(output) as connection:
        connection.execute("PRAGMA foreign_keys = ON")

        checks = [
            ("poems", len(catalog["poems"])),
            ("poem_lines", sum(len(poem["lines"]) for poem in catalog["poems"])),
            ("poem_tags", sum(len(poem["tags"]) for poem in catalog["poems"])),
            ("poem_themes", sum(len(poem.get("themes", [])) for poem in catalog["poems"])),
            ("collections", len(catalog["collections"])),
            ("collection_poems", sum(len(collection_data["poemIDs"]) for collection_data in catalog["collections"])),
            ("categories", len(catalog["categories"])),
        ]
        for table, expected_count in checks:
            count = connection.execute(f"SELECT COUNT(*) FROM {table}").fetchone()[0]
            if count != expected_count:
                raise ValueError(f"{output} table {table} expected {expected_count} rows, got {count}")

        invalid_collection_refs = connection.execute(
            """
            SELECT COUNT(*)
            FROM collection_poems
            LEFT JOIN poems ON poems.id = collection_poems.poem_id
            WHERE poems.id IS NULL
            """
        ).fetchone()[0]
        if invalid_collection_refs:
            raise ValueError(f"{output} has {invalid_collection_refs} invalid collection poem references")

        search_gram_count = connection.execute("SELECT COUNT(*) FROM search_grams").fetchone()[0]
        if search_gram_count == 0:
            raise ValueError(f"{output} has no search gram coverage")


def build_notice(report: dict[str, Any]) -> str:
    generated_at = dt.datetime.now(dt.timezone.utc).replace(microsecond=0).isoformat()
    license_text = fetch_text("LICENSE").strip()
    source_lines = "\n".join(
        f"- {source['label']}: {BLOB_BASE_URL}/{source['path']} ({report['source_counts'][source_id]} items)"
        for source_id, source in SOURCES.items()
    )
    return f"""Poemery bundled poetry data notice

Data source: {REPOSITORY_URL}
Pinned commit: {COMMIT}
Generated at: {generated_at}

Source files:
{source_lines}

The bundled poems are converted from the chinese-poetry/chinese-poetry repository.
Poemery preserves the upstream text shape and does not include modern commentary,
translation, or appreciation text from third-party websites.

Original repository license:

{license_text}
"""


if __name__ == "__main__":
    sys.exit(main())
