#!/usr/bin/env python3
import os
from pathlib import Path
import shutil
import sys
args = sys.argv[1:]
# Quarto sends source and destination as the first two positional paths.
# Relative paths avoid Dart Sass's input:output parsing of parent directory colons.
for i in range(min(2, len(args))):
    if os.path.isabs(args[i]):
        args[i] = os.path.relpath(args[i])
sass = shutil.which("sass")
if sass is None:
    raise SystemExit("Sass executable absent from locked environment")
prefix = Path(os.environ["CONDA_PREFIX"]).resolve()
if not Path(sass).resolve().is_relative_to(prefix):
    raise SystemExit("Sass must belong to the locked Pixi environment")
os.execv(sass, [sass, *args])
