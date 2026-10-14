"""Build the installable addon from an explicit runtime file list."""
import argparse
import os
from pathlib import Path
import re
from zipfile import ZipFile, ZIP_DEFLATED

ROOT = Path(__file__).resolve().parents[1]
toc = ROOT / "VanillaVarnish.toc"
source = toc.read_text(encoding="utf-8")
version = re.search(r"^## Version: ([\w.\-]+)$", source, re.MULTILINE).group(1)
runtime = [ROOT / line.replace("\\", "/") for line in source.splitlines()
           if line.strip() and not line.startswith("#")]
files = [toc, ROOT / "README.md", ROOT / "CHANGELOG.md", ROOT / "LICENSE", *runtime]
for folder in ("Media", "Textures", "Licenses"):
    files.extend(path for path in (ROOT / folder).iterdir() if path.is_file())
for path in files:
    if not path.is_file():
        raise SystemExit(f"Missing release file: {path}")
    if not path.resolve().is_relative_to(ROOT.resolve()):
        raise SystemExit(f"Release file outside addon: {path}")
out = ROOT / "dist" / f"VanillaVarnish-{version}.zip"
out.parent.mkdir(exist_ok=True)
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--check-committed", action="store_true", help="Require the checked-in ZIP to match current release sources")
args = parser.parse_args()
expected = {}
for path in sorted(set(files)):
    data = path.read_bytes()
    if path.suffix in {".lua", ".toc", ".md", ".txt"} or path.name == "LICENSE":
        data = data.replace(b"\r\n", b"\n")
    expected["VanillaVarnish/" + path.relative_to(ROOT).as_posix()] = data
if args.check_committed:
    if not out.is_file():
        raise SystemExit(f"Commit the release archive first: {out.name}")
    with ZipFile(out) as archive:
        if archive.testzip() is not None or len(archive.namelist()) != len(expected) or set(archive.namelist()) != set(expected):
            raise SystemExit("Committed archive has unexpected or missing files")
        if any(archive.read(name) != data for name, data in expected.items()):
            raise SystemExit("Committed archive does not match release sources; rebuild and commit it")
with ZipFile(out, "w", compression=ZIP_DEFLATED) as archive:
    for name, data in expected.items():
        archive.writestr(name, data)
with ZipFile(out) as archive:
    assert archive.testzip() is None
    names = archive.namelist()
    assert all(name.startswith("VanillaVarnish/") for name in names)
    assert "VanillaVarnish/VanillaVarnish.toc" in names
    assert "VanillaVarnish/Media/Montserrat-OFL.txt" in names
    assert "VanillaVarnish/LICENSE" in names
    assert "VanillaVarnish/Licenses/pfQuest-MIT.txt" in names
    assert "VanillaVarnish/Licenses/VMaNGOS-GPL-2.0.txt" in names
    assert "VanillaVarnish/Licenses/QuestDropData-NOTICES.txt" in names
    assert not any(part in {"tests", "tools", ".test-deps", "dist", ".git", ".github", "Branding"}
                   for name in names for part in name.split("/"))
    assert not any(name.endswith((".exe", ".pyd", ".pyc", ".py")) for name in names)
print(f"Built {out} ({len(names)} files; {out.stat().st_size:,} bytes)")
if os.environ.get("GITHUB_OUTPUT"):
    with open(os.environ["GITHUB_OUTPUT"], "a", encoding="utf-8") as stream:
        stream.write(f"archive=dist/{out.name}\n")
