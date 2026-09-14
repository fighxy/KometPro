import json
import os

assets = []
with open(os.environ['INDEX_FILE'], encoding='utf-8') as f:
    for line in f:
        line = line.rstrip('\n')
        if not line:
            continue
        name, size, digest = line.split('\t')
        assets.append({
            'name': name,
            'url': f"{os.environ['ASSET_BASE']}/{name}",
            'size': int(size),
            'sha256': digest,
        })
assets.sort(key=lambda a: a['name'])

manifest = {
    'version': os.environ['VERSION'],
    'build': int(os.environ['BUILD']),
    'tag': os.environ['TAG'],
    'commit': os.environ.get('COMMIT') or '',
    'url': os.environ['RELEASE_URL'],
    'notes': '',
    'assets': assets,
}

dist_dir = os.environ['DIST_DIR']

with open(f'{dist_dir}/latest.json', 'w', encoding='utf-8') as f:
    json.dump(manifest, f, ensure_ascii=False, indent=2)
    f.write('\n')

with open(f'{dist_dir}/checksums.txt', 'w', encoding='utf-8') as f:
    for asset in assets:
        f.write(f"{asset['sha256']}  {asset['name']}\n")
