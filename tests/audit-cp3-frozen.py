"""Check frozen artifact bytes and protect existing CP1/CP2 code/results."""
from pathlib import Path
import hashlib,json
root=Path('.')
expected='a7d30c2eb219ba3eb80ec55f37acea7014b1aa0ce588de6ade04d28e255b3556'
for file in ['artifacts/cp2_final_model.rds','output/cp2_final_model.rds']:
    if Path(file).exists():
        assert hashlib.sha256(Path(file).read_bytes()).hexdigest()==expected,file
assert Path('artifacts/cp2_final_model.rds').exists()
baseline=Path('output/cp3_protected_baseline.json')
if baseline.exists():
    for file,digest in json.loads(baseline.read_text()).items():
        if file in ['pixi.toml','README.md']: continue
        if file=='_quarto.yml':
            assert hashlib.sha256(Path(file).read_bytes().replace(b'    - checkpoint3.qmd\n',b'')).hexdigest()==digest,file
            continue
        assert hashlib.sha256(Path(file).read_bytes()).hexdigest()==digest,file
print('Frozen artifact and protected CP1/CP2 files passed.')
