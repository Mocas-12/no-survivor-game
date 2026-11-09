"""Publish a version-named Godot Web export into docs without touching documentation."""
import hashlib, json, re, shutil, sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SOURCE = sys.argv[1] if len(sys.argv) > 1 else '266eae6'
assert re.fullmatch(r'[0-9a-f]{7,40}', SOURCE), 'Expected a Git source hash'
BUILD = 'salvage-' + SOURCE
PREFIX = 'game-' + SOURCE
export = ROOT / 'build' / 'release'
target = (ROOT / 'docs').resolve()
required = [PREFIX + ext for ext in ['.html', '.js', '.pck', '.wasm']]
assert all((export / name).is_file() for name in required), 'Export version-named Web files first'
html = (export / (PREFIX + '.html')).read_text(encoding='utf-8')
assert '"executable":"' + PREFIX + '"' in html
assert PREFIX + '.js' in html
pack = export / (PREFIX + '.pck')
assert pack.stat().st_size < 100 * 1024 * 1024, 'Package exceeds GitHub individual-file limit'
html = html.replace('</head>', '<meta name="no-survivor-build" content="' + BUILD + '" />\n</head>')
generated = re.compile(r'^(index|game-[0-9a-f]{7,40})\.(html|js|pck|wasm|png|icon\.png|apple-touch-icon\.png|audio\.worklet\.js|audio\.position\.worklet\.js)$')
for old in target.iterdir():
    if old.is_file() and generated.fullmatch(old.name):
        assert old.resolve().parent == target
        old.unlink()
for file in export.iterdir():
    if file.is_file() and file.name.startswith(PREFIX + '.') and file.suffix != '.html' and not file.name.endswith('.import'):
        shutil.copy2(file, target / file.name)
(target / 'index.html').write_text(html, encoding='utf-8')
info = {'build': BUILD, 'source': SOURCE, 'executable': PREFIX,
        'pck_sha256': hashlib.sha256(pack.read_bytes()).hexdigest(),
        'pck_bytes': pack.stat().st_size}
(target / 'build-info.json').write_text(json.dumps(info, indent=2) + '\n', encoding='utf-8')
assert hashlib.sha256((target / (PREFIX + '.pck')).read_bytes()).hexdigest() == info['pck_sha256']
print(json.dumps(info))
