#!/usr/bin/env python3
"""Fetch trustworthy offline author introductions from Chinese Wikipedia."""

from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import json
import re
import sqlite3
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path
from typing import Any


DEFAULT_API_BASE = "https://zh.wikipedia.org/w/api.php"
LITERARY_TERMS = ("诗人", "詩人", "词人", "詞人", "文学家", "文學家", "作家", "散曲", "戏曲", "戲曲")
ANONYMOUS_MARKERS = ("佚名", "无名氏", "無名氏", "不详", "不詳")
DYNASTY_TERMS = {
    "先秦": ("先秦", "战国", "戰國", "春秋", "楚国", "楚國"),
    "汉": ("汉朝", "漢朝", "东汉", "東漢", "西汉", "西漢", "汉末", "漢末"),
    "魏晋": ("魏晋", "魏晉", "三国", "三國", "西晋", "西晉", "东晋", "東晉"),
    "南北朝": ("南北朝", "南朝", "北朝"),
    "唐": ("唐朝", "唐代", "盛唐", "中唐", "晚唐"),
    "五代": ("五代", "南唐", "后蜀", "後蜀"),
    "宋": ("宋朝", "宋代", "北宋", "南宋"),
    "元": ("元朝", "元代"),
    "明": ("明朝", "明代"),
    "清": ("清朝", "清代"),
}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--sqlite", default="Poemery/PoemLibrary.sqlite")
    parser.add_argument("--output", default="Scripts/AuthorProfiles.json")
    parser.add_argument("--report", default="Scripts/AuthorProfilesReport.json")
    parser.add_argument("--api-base", default=DEFAULT_API_BASE)
    parser.add_argument("--cache-dir", default=str(Path.home() / "Library/Caches/PoemeryImporter/AuthorProfiles"))
    parser.add_argument("--offline", action="store_true")
    parser.add_argument("--batch-size", type=int, default=8)
    parser.add_argument("--attempts", type=int, default=4)
    parser.add_argument("--timeout", type=float, default=15)
    parser.add_argument("--minimum-matches", type=int, default=20)
    args = parser.parse_args()

    authors = read_authors(Path(args.sqlite))
    profiles, report = fetch_profiles(
        authors=authors,
        api_base=args.api_base,
        cache_dir=Path(args.cache_dir),
        offline=args.offline,
        batch_size=max(1, min(args.batch_size, 10)),
        attempts=max(1, args.attempts),
        timeout=max(1, args.timeout),
    )

    output = Path(args.output)
    previous_count = existing_profile_count(output)
    required_count = max(args.minimum_matches, previous_count)
    if len(profiles) < required_count:
        raise RuntimeError(
            f"Refusing to replace {output}: fetched {len(profiles)} trusted profiles, "
            f"but at least {required_count} are required"
        )

    write_json_atomically(output, profiles)
    write_json_atomically(Path(args.report), report)
    print(f"Wrote {output} ({len(profiles)} trusted profiles)")
    print(f"Wrote {args.report}")
    return 0


def read_authors(sqlite_path: Path) -> list[dict[str, Any]]:
    with sqlite3.connect(f"file:{sqlite_path}?mode=ro", uri=True) as connection:
        rows = connection.execute(
            "SELECT id, name, dynasty, poem_count FROM authors ORDER BY poem_count DESC, name, id"
        ).fetchall()
    return [
        {"id": row[0], "name": row[1], "dynasty": row[2], "poemCount": row[3]}
        for row in rows
    ]


def fetch_profiles(
    authors: list[dict[str, Any]],
    api_base: str,
    cache_dir: Path,
    offline: bool,
    batch_size: int,
    attempts: int,
    timeout: float,
) -> tuple[list[dict[str, Any]], dict[str, Any]]:
    profiles: list[dict[str, Any]] = []
    missing: list[str] = []
    ambiguous: list[str] = []
    skipped: list[str] = []
    unavailable: list[str] = []

    cache_dir.mkdir(parents=True, exist_ok=True)
    eligible = []
    for author in authors:
        if any(marker in author["name"] for marker in ANONYMOUS_MARKERS):
            skipped.append(author_label(author))
        else:
            eligible.append(author)

    for start in range(0, len(eligible), batch_size):
        batch = eligible[start : start + batch_size]
        candidates_by_author = {author["id"]: title_candidates(author["name"]) for author in batch}
        titles = [title for author in batch for title in candidates_by_author[author["id"]]]
        try:
            payload = mediawiki_query(
                api_base=api_base,
                titles=titles,
                cache_dir=cache_dir,
                offline=offline,
                attempts=attempts,
                timeout=timeout,
            )
        except (OSError, ValueError, urllib.error.URLError) as error:
            unavailable.extend(author_label(author) for author in batch)
            print(f"Batch unavailable at {start}: {error}")
            continue

        pages = pages_by_title(payload)
        redirects = redirect_map(payload)
        for author in batch:
            matched_page = None
            saw_page = False
            for candidate in candidates_by_author[author["id"]]:
                target = redirects.get(canonical_title(candidate), canonical_title(candidate))
                page = pages.get(target)
                if not page or page.get("missing") is True:
                    continue
                saw_page = True
                if is_trusted_match(author, page):
                    matched_page = page
                    break
            if matched_page is None:
                (ambiguous if saw_page else missing).append(author_label(author))
                continue
            profiles.append(profile_from_page(author, matched_page))

    profiles.sort(key=lambda profile: profile["id"])
    report = {
        "generatedAt": dt.datetime.now(dt.timezone.utc).replace(microsecond=0).isoformat(),
        "apiBase": api_base,
        "authorCount": len(authors),
        "matchedCount": len(profiles),
        "missing": missing,
        "ambiguous": ambiguous,
        "skipped": skipped,
        "unavailable": unavailable,
    }
    return profiles, report


def title_candidates(name: str) -> list[str]:
    base_name = name.split("《", 1)[0].strip()
    return [base_name, *[f"{base_name} ({suffix})" for suffix in ("诗人", "词人", "文学家", "作家")]]


def mediawiki_query(
    api_base: str,
    titles: list[str],
    cache_dir: Path,
    offline: bool,
    attempts: int,
    timeout: float,
) -> dict[str, Any]:
    url = mediawiki_request_url(api_base, titles)
    cache_path = cache_dir / f"{hashlib.sha256(url.encode()).hexdigest()}.json"
    if cache_path.exists():
        return json.loads(cache_path.read_text(encoding="utf-8"))
    if offline:
        raise OSError(f"No cached response for {titles[0]}")

    request = urllib.request.Request(
        url,
        headers={
            "User-Agent": "PoemeryAuthorImporter/1.0 (offline iOS poetry library; contact: local-build)",
            "Accept": "application/json",
            "Accept-Encoding": "identity",
        },
    )
    last_error: Exception | None = None
    for attempt in range(attempts):
        try:
            with urllib.request.urlopen(request, timeout=timeout) as response:
                payload = json.loads(response.read().decode("utf-8"))
            if "error" in payload:
                raise ValueError(payload["error"])
            write_json_atomically(cache_path, payload)
            return payload
        except (OSError, ValueError, urllib.error.URLError) as error:
            last_error = error
            if attempt + 1 < attempts:
                time.sleep(min(8, 2**attempt))
    raise OSError(f"MediaWiki request failed after {attempts} attempts: {last_error}")


def mediawiki_request_url(api_base: str, titles: list[str]) -> str:
    params = urllib.parse.urlencode(
        {
            "action": "query",
            "format": "json",
            "formatversion": "2",
            "redirects": "1",
            "prop": "extracts|info|revisions",
            "exintro": "1",
            "explaintext": "1",
            "exsentences": "3",
            "inprop": "url",
            "rvprop": "ids",
            "variant": "zh-cn",
            "maxlag": "2",
            "titles": "|".join(titles),
        }
    )
    return f"{api_base}?{params}"


def pages_by_title(payload: dict[str, Any]) -> dict[str, dict[str, Any]]:
    return {
        canonical_title(page.get("title", "")): page
        for page in payload.get("query", {}).get("pages", [])
    }


def redirect_map(payload: dict[str, Any]) -> dict[str, str]:
    redirects = payload.get("query", {}).get("redirects", [])
    return {
        canonical_title(item.get("from", "")): canonical_title(item.get("to", ""))
        for item in redirects
    }


def canonical_title(value: str) -> str:
    return re.sub(r"\s+", " ", value.replace("_", " ")).strip()


def is_trusted_match(author: dict[str, Any], page: dict[str, Any]) -> bool:
    extract = page.get("extract", "")
    if not extract or not any(term in extract for term in LITERARY_TERMS):
        return False
    dynasty_terms = DYNASTY_TERMS.get(author["dynasty"], (author["dynasty"],))
    return not dynasty_terms or any(term in extract for term in dynasty_terms)


def profile_from_page(author: dict[str, Any], page: dict[str, Any]) -> dict[str, Any]:
    revision = (page.get("revisions") or [{}])[0].get("revid")
    return {
        "id": author["id"],
        "name": author["name"],
        "dynasty": author["dynasty"],
        "biography": concise_extract(page.get("extract", "")),
        "lifeYears": None,
        "courtesyNames": [],
        "aliases": [],
        "nativePlace": None,
        "sourceName": "中文维基百科",
        "sourceURL": page.get("fullurl"),
        "sourceLicense": "CC BY-SA 4.0",
        "sourceRevisionID": revision,
        "sourceFetchedAt": dt.datetime.now(dt.timezone.utc).replace(microsecond=0).isoformat(),
        "portrait": None,
    }


def concise_extract(extract: str) -> str:
    normalized = re.sub(r"\s+", " ", extract).strip()
    sentences = [sentence.strip() for sentence in re.split(r"(?<=[。！？!?])", normalized) if sentence.strip()]
    return "".join(sentences[:3])


def author_label(author: dict[str, Any]) -> str:
    return f"{author['dynasty']}|{author['name']}"


def existing_profile_count(output: Path) -> int:
    if not output.exists():
        return 0
    try:
        payload = json.loads(output.read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return 0
    return len(payload) if isinstance(payload, list) else 0


def write_json_atomically(path: Path, value: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_name(f"{path.name}.tmp")
    try:
        temporary.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        temporary.replace(path)
    finally:
        if temporary.exists():
            temporary.unlink()


if __name__ == "__main__":
    raise SystemExit(main())
