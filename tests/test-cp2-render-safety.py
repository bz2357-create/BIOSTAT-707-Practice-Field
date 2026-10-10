"""Check the actual Quarto entry command preserves existing output artifacts."""
from pathlib import Path
import os
import shutil
import subprocess
import tempfile

root = Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix="cp2:render-safety-" if os.name != "nt" else "cp2-render-safety-") as directory:
    work = Path(directory)
    shutil.copy2(root / "_quarto.yml", work / "_quarto.yml")
    (work / "checkpoint1.qmd").write_text("---\ntitle: Fixture only\n---\nCP1 fixture.\n")
    header = (root / "checkpoint2.qmd").read_text().split("---", 2)[1]
    (work / "checkpoint2.qmd").write_text("---" + header + "---\n" + """
```{r}
stopifnot(file.exists('output/checkpoint1.html'), file.exists('output/existing.csv'))
writeLines('new artifact', 'output/model-fixture.txt')
```
""")
    output = work / "output"
    output.mkdir()
    preserved = {"checkpoint1.html": b"CP1 fixture HTML", "existing.csv": b"x\n1\n"}
    for name, content in preserved.items():
        (output / name).write_bytes(content)
    environment = dict(os.environ)
    if os.name != "nt":
        if ":" in str(root):
            assert environment.get("QUARTO_DART_SASS") == str(root / "scripts" / "quarto-sass.py"), "Pixi activation must replace the package default"
        environment["QUARTO_DART_SASS"] = str(root / "scripts" / "quarto-sass.py")
    subprocess.run(["quarto", "render", "checkpoint2.qmd", "--output-dir", "output"],
                   cwd=work, env=environment, check=True)
    for name, content in preserved.items():
        assert (output / name).read_bytes() == content, name
    assert (output / "checkpoint2.html").stat().st_size > 0
    assert (output / "model-fixture.txt").read_text().strip() == "new artifact"
print("CP2 exact-command Quarto artifact-preservation fixture passed.")
