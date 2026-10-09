"""Build and verify a clean CurseForge upload candidate without publishing it."""
from pathlib import Path
import re
from zipfile import ZipFile, ZIP_DEFLATED

ROOT = Path(__file__).resolve().parents[1]
toc = ROOT / "VanillaVarnish.toc"
source = toc.read_text(encoding="utf-8")
version = re.search(r"^## Version: ([\w.\-]+)$", source, re.MULTILINE).group(1)
runtime = [ROOT / line.replace("\\", "/") for line in source.splitlines()
           if line.strip() and not line.startswith("#")]
files = [toc, ROOT / "README.md", ROOT / "CHANGELOG.md", *runtime]
for folder in ("Media", "Textures"):
    files.extend(path for path in (ROOT / folder).iterdir() if path.is_file())
for path in files:
    if not path.is_file():
        raise SystemExit(f"Missing release file: {path}")
    if not path.resolve().is_relative_to(ROOT.resolve()):
        raise SystemExit(f"Release file outside addon: {path}")
out = ROOT / "dist" / f"VanillaVarnish-{version}.zip"
out.parent.mkdir(exist_ok=True)
with ZipFile(out, "w", compression=ZIP_DEFLATED) as archive:
    for path in sorted(set(files)):
        archive.write(path, "VanillaVarnish/" + path.relative_to(ROOT).as_posix())
with ZipFile(out) as archive:
    assert archive.testzip() is None
    names = archive.namelist()
    assert all(name.startswith("VanillaVarnish/") for name in names)
    assert "VanillaVarnish/VanillaVarnish.toc" in names
    assert "VanillaVarnish/Media/Montserrat-OFL.txt" in names
    assert not any(part in {"tests", "tools", ".test-deps", "dist", ".git"}
                   for name in names for part in name.split("/"))
    assert not any(name.endswith((".exe", ".pyd", ".pyc", ".py")) for name in names)
print(f"Built {out} ({len(names)} files; {out.stat().st_size:,} bytes)")
