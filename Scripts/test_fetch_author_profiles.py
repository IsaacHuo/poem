#!/usr/bin/env python3

import hashlib
import json
import tempfile
import unittest
from pathlib import Path

import fetch_author_profiles as importer


class AuthorProfileImporterTests(unittest.TestCase):
    def setUp(self):
        self.author = {
            "id": "cp-author-li-bai",
            "name": "李白",
            "dynasty": "唐",
            "poemCount": 51,
        }

    def test_exact_title_and_redirect_resolve_to_trusted_page(self):
        payload = {
            "query": {
                "redirects": [{"from": "李太白", "to": "李白"}],
                "pages": [{"title": "李白", "extract": "李白是唐朝诗人、作家。"}],
            }
        }

        pages = importer.pages_by_title(payload)
        redirects = importer.redirect_map(payload)

        self.assertEqual(redirects["李太白"], "李白")
        self.assertTrue(importer.is_trusted_match(self.author, pages["李白"]))
        self.assertEqual(importer.title_candidates("李白")[0], "李白")

    def test_wrong_dynasty_is_rejected_as_ambiguous(self):
        page = {"title": "李白", "extract": "李白是北宋词人、文学家。"}

        self.assertFalse(importer.is_trusted_match(self.author, page))

    def test_offline_mode_rebuilds_from_persistent_cache(self):
        titles = importer.title_candidates("李白")
        api_base = "https://example.test/w/api.php"
        payload = {"query": {"pages": [{"title": "李白", "extract": "李白是唐朝诗人。"}]}}
        with tempfile.TemporaryDirectory() as directory:
            cache_dir = Path(directory)
            url = importer.mediawiki_request_url(api_base, titles)
            cache_path = cache_dir / f"{hashlib.sha256(url.encode()).hexdigest()}.json"
            cache_path.write_text(json.dumps(payload), encoding="utf-8")

            restored = importer.mediawiki_query(
                api_base=api_base,
                titles=titles,
                cache_dir=cache_dir,
                offline=True,
                attempts=1,
                timeout=1,
            )

        self.assertEqual(restored, payload)

    def test_profile_contains_source_metadata_without_collection_template(self):
        page = {
            "title": "李白",
            "extract": "李白是唐朝诗人。其诗想象丰富。",
            "fullurl": "https://zh.wikipedia.org/wiki/李白",
            "revisions": [{"revid": 123}],
        }

        profile = importer.profile_from_page(self.author, page)

        self.assertEqual(profile["sourceRevisionID"], 123)
        self.assertEqual(profile["sourceLicense"], "CC BY-SA 4.0")
        self.assertNotIn("Poemery 当前收录", profile["biography"])
        self.assertNotIn("作品目录", profile["biography"])


if __name__ == "__main__":
    unittest.main()
