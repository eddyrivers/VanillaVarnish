"""Publish a tested version-tag archive to the CurseForge author Upload API."""
import argparse
import json
import os
from pathlib import Path
import re
from urllib.error import HTTPError, URLError
from urllib.request import HTTPRedirectHandler, Request, build_opener
from uuid import uuid4
from zipfile import ZipFile

ROOT = Path(__file__).resolve().parents[1]
API = "https://wow.curseforge.com/api"
GAME_VERSION = "1.60.1"
# CurseForge's Forever version family, also used by BigWigsMods/packager.
FOREVER_TYPE = 88568


class NoRedirects(HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        # An upload credential must stay on its intended API host.
        return None


def request_json(path, token, data=None, content_type=None):
    headers = {"X-Api-Token": token, "Accept": "application/json", "User-Agent": "VanillaVarnish-release"}
    if content_type:
        headers["Content-Type"] = content_type
    request = Request(API + path, data=data, headers=headers)
    try:
        with build_opener(NoRedirects).open(request, timeout=90) as response:
            return json.load(response)
    except HTTPError as error:
        # Do not echo server bodies, request headers, or credentials into CI logs.
        raise RuntimeError(f"CurseForge API returned HTTP {error.code}") from None
    except (URLError, TimeoutError, json.JSONDecodeError):
        raise RuntimeError("CurseForge response unavailable; check the project's Files page before retrying an upload") from None


def release_info(root, tag):
    toc = (root / "VanillaVarnish.toc").read_text(encoding="utf-8")
    def field(name):
        match = re.search(r"^## " + re.escape(name) + r": (.+)$", toc, re.MULTILINE)
        if not match:
            raise ValueError(f"Missing TOC field: {name}")
        return match.group(1).strip()
    version, project = field("Version"), field("X-Curse-Project-ID")
    if not re.fullmatch(r"\d+\.\d+\.\d+(?:-(?:alpha|beta)(?:\.\d+)?)?", version) or tag != "v" + version:
        raise ValueError("Release tag must exactly match v<TOC version>")
    if field("Interface") != "16001" or not project.isdecimal():
        raise ValueError("Publishing requires Interface 16001 and a numeric CurseForge project ID")
    notes = (root / "CHANGELOG.md").read_text(encoding="utf-8")
    match = re.search(r"^## " + re.escape(version) + r"\s*\n(.*?)(?=^## |\Z)", notes, re.MULTILINE | re.DOTALL)
    if not match or not match.group(1).strip():
        raise ValueError("Add release notes for the TOC version before publishing")
    release_type = "alpha" if "-alpha" in version else "beta" if "-beta" in version else "release"
    archive = root / "dist" / f"VanillaVarnish-{version}.zip"
    with ZipFile(archive) as package:
        if package.testzip() is not None:
            raise ValueError("Release archive failed its integrity check")
        if package.read("VanillaVarnish/VanillaVarnish.toc").replace(b"\r\n", b"\n") != (root / "VanillaVarnish.toc").read_bytes().replace(b"\r\n", b"\n"):
            raise ValueError("Release archive has a stale TOC")
    return project, version, release_type, match.group(1).strip(), archive


def game_version_id(versions):
    matches = [v for v in versions if v.get("gameVersionTypeID") == FOREVER_TYPE and v.get("name") == GAME_VERSION]
    if len(matches) != 1 or type(matches[0].get("id")) is not int:
        raise ValueError("No unique CurseForge Forever 1.60.1 game version; refusing to label another client compatible")
    return matches[0]["id"]


def multipart(metadata, archive):
    boundary = "vv-" + uuid4().hex
    parts = [
        f'--{boundary}\r\nContent-Disposition: form-data; name="metadata"\r\nContent-Type: application/json\r\n\r\n'.encode(),
        json.dumps(metadata).encode(),
        f'\r\n--{boundary}\r\nContent-Disposition: form-data; name="file"; filename="{archive.name}"\r\nContent-Type: application/zip\r\n\r\n'.encode(),
        archive.read_bytes(),
        f"\r\n--{boundary}--\r\n".encode(),
    ]
    return b"".join(parts), "multipart/form-data; boundary=" + boundary


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--tag", required=True)
    parser.add_argument("--check", action="store_true", help="Validate release metadata without network access or upload")
    args = parser.parse_args()
    try:
        project, version, release_type, notes, archive = release_info(ROOT, args.tag)
        if args.check:
            print(f"Validated {archive.name} for project {project}, {release_type}, Forever {GAME_VERSION}")
            return
        token = os.environ.get("CF_API_TOKEN", "").strip()
        if not token:
            raise ValueError("Set the repository Actions secret CF_API_TOKEN before publishing")
        game_id = game_version_id(request_json("/game/wow/versions", token))
        metadata = {"displayName": f"VanillaVarnish {version}", "gameVersions": [game_id],
                    "releaseType": release_type, "changelog": notes, "changelogType": "markdown"}
        data, content_type = multipart(metadata, archive)
        result = request_json(f"/projects/{project}/upload-file", token, data, content_type)
        if not isinstance(result, dict) or type(result.get("id")) is not int:
            raise RuntimeError("Upload outcome unclear; check CurseForge Files before retrying")
        print(f"Uploaded {archive.name} to CurseForge project {project}; file ID {result['id']}. Approval may still be pending.")
        summary = os.environ.get("GITHUB_STEP_SUMMARY")
        if summary:
            with open(summary, "a", encoding="utf-8") as stream:
                stream.write(f"Uploaded **{version}** to CurseForge; file ID **{result['id']}**, **{release_type}**, Forever **{GAME_VERSION}**.\n")
    except (ValueError, RuntimeError, OSError) as error:
        raise SystemExit(str(error)) from None


if __name__ == "__main__":
    main()
