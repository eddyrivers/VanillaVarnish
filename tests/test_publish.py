"""Publishing must never silently label an unsupported client or stale package."""
import importlib.util
from pathlib import Path
import tempfile
import unittest
from urllib.error import HTTPError
from unittest.mock import patch
from zipfile import ZipFile

spec = importlib.util.spec_from_file_location("publisher", Path(__file__).resolve().parents[1] / "tools/publish_curseforge.py")
publisher = importlib.util.module_from_spec(spec)
spec.loader.exec_module(publisher)


class PublishingTests(unittest.TestCase):
    def fixture(self, root, version="1.2.3"):
        toc = f"## Interface: 16001\n## Version: {version}\n## X-Curse-Project-ID: 1736142\n"
        (root / "VanillaVarnish.toc").write_text(toc, encoding="utf-8")
        (root / "CHANGELOG.md").write_text(f"# Changelog\n\n## {version}\n\n- Current notes.\n\n## 1.2.2\n\n- Old notes.\n", encoding="utf-8")
        (root / "dist").mkdir(exist_ok=True)
        archive = root / "dist" / f"VanillaVarnish-{version}.zip"
        with ZipFile(archive, "w") as zipfile:
            zipfile.writestr("VanillaVarnish/VanillaVarnish.toc", (root / "VanillaVarnish.toc").read_bytes())
        return archive

    def test_exact_tag_and_current_notes(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            self.fixture(root)
            project, version, kind, notes, _ = publisher.release_info(root, "v1.2.3")
            self.assertEqual((project, version, kind, notes), ("1736142", "1.2.3", "release", "- Current notes."))
            for tag in ("main", "v1.2.2", "1.2.3"):
                with self.assertRaises(ValueError):
                    publisher.release_info(root, tag)

    def test_prerelease_types(self):
        for suffix in ("alpha", "beta.1"):
            with tempfile.TemporaryDirectory() as tmp:
                root = Path(tmp)
                self.fixture(root, "1.2.3-" + suffix)
                self.assertEqual(publisher.release_info(root, "v1.2.3-" + suffix)[2], suffix.split(".")[0])

    def test_stale_toc_and_missing_notes(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            self.fixture(root)
            toc = root / "VanillaVarnish.toc"
            toc.write_text(toc.read_text() + "# changed\n", encoding="utf-8")
            with self.assertRaisesRegex(ValueError, "stale TOC"):
                publisher.release_info(root, "v1.2.3")
            (root / "CHANGELOG.md").write_text("# Changelog\n\n## 1.2.2\n- Old notes.\n", encoding="utf-8")
            with self.assertRaisesRegex(ValueError, "release notes"):
                publisher.release_info(root, "v1.2.3")

    def test_forever_version_has_no_fallback(self):
        good = {"id": 123, "name": "1.60.1", "gameVersionTypeID": 88568}
        other = {"id": 456, "name": "1.60.1", "gameVersionTypeID": 67408}
        self.assertEqual(publisher.game_version_id([other, good]), 123)
        for versions in ([], [other], [good, good], [dict(good, name="1.60.2")]):
            with self.assertRaises(ValueError):
                publisher.game_version_id(versions)

    def test_http_error_does_not_echo_credentials(self):
        error = HTTPError(publisher.API, 403, "secret server detail", {}, None)
        with patch.object(publisher, "build_opener") as opener:
            opener.return_value.open.side_effect = error
            with self.assertRaisesRegex(RuntimeError, "^CurseForge API returned HTTP 403$"):
                publisher.request_json("/game/wow/versions", "secret token")
        self.assertIsNone(publisher.NoRedirects().redirect_request(None, None, 302, "", {}, "https://other.example"))


if __name__ == "__main__":
    unittest.main()
