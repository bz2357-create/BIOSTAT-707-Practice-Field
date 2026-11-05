# BIOSTAT 707 Checkpoints 1 and 2

With Pixi installed and the supplied files in `data/set-a/` and
`data/Outcomes-a.txt`, run from the repository root:

```sh
pixi run --locked checkpoint1
pixi run --locked checkpoint2
```

Each command is independent. Checkpoint 2 reconstructs its table directly from
these raw Set A inputs; it needs no earlier CP1 render or generated CSV. It
compares elastic-net logistic regression, a prespecified logistic GAM and a
probability random forest by common five-fold outer CV, with three-fold inner
tuning for elastic net/forest, and evaluates SAPS-I and SOFA as raw benchmarks.
It uses no other clinical inputs and downloads no data during rendering.

The locked R/Quarto/Pixi environment retains Linux, Apple Silicon macOS, Intel
macOS and Windows platforms. For a checkout whose path contains a colon, use
`pixi config set --local detached-environments true` once to avoid an invalid
PATH prefix. This local installation configuration is already enabled in the
development checkout; ordinary fresh checkout paths need no extra setup command.
POSIX activation also handles the Quarto/Sass colon-path argument bug.
`_quarto.yml` prevents standalone output-directory cleanup from deleting existing
CP1 artifacts when running either named task.

Outputs are self-contained `output/checkpoint1.html` and
`output/checkpoint2.html`. Only rendered reports are versioned
among generated outputs; data, models and CSVs stay ignored. CP1 also writes
its existing long/wide tables and audits. CP2 writes `output/cp2_modeling_table.csv`,
`output/cp2_final_model.rds`, `output/cp2_oof_predictions.csv`, plus fold/tuning,
preprocessing, cleaning, dictionary, performance and interpretation artifacts.
The final bundle includes fitted preprocessing. `cp2_predict(bundle, predictors)`
in `R/cp2-models.R` consumes a constructed predictor table and requires no outcome
or refit. Its saved predictor-only fixture checks reload agreement within 1e-12.
OOF model probabilities are exported with 17 significant digits. The pipeline
computes reported metrics and ROC curves from that newly written CSV, so tiny
floating-point parser differences cannot change their recomputation.

Tests (after supplying Set A for integration/regression):

```sh
pixi run --locked Rscript tests/test-loader.R
pixi run --locked Rscript tests/test-cp2-plots.R
pixi run --locked Rscript tests/test-cp2-results.R
pixi run --locked Rscript tests/test-cp2-artifacts.R
pixi run --locked Rscript tests/test-cp2-reload.R
pixi run --locked Rscript tests/test-cp2-partitions.R
pixi run --locked Rscript tests/cp2-qa-extremes.R
pixi run --locked python tests/test-cp2-render-safety.py
pixi run --locked python tests/test-cp2-report.py
```

The plots fixture command includes data/preprocessing and real-estimator/tuning
fixtures; the artifact test requires a completed CP2 render. Actual runtime,
commands, exit statuses, warning limitations and the section-by-section checklist
are recorded in `docs/cp2-verification.md` and ignored `output/cp2_*` logs.
The 500-tree training-only timing smoke took 10.605 seconds. The final complete
locked CP2 render passed in the main checkout; measured analysis pipeline
time was 570.293 seconds (9.505 minutes), on Darwin arm64, eight logical cores,
with one ranger/BLAS thread. An earlier input-only exported snapshot also rendered
successfully in 585.894 seconds, before the final CSV-precision/render fixes.
Environment installation and development/debugging time are separate.

Checkpoint 2 documents ChatGPT and OpenAI Codex assistance in its opening
AI-use statement. Its GAM diagnostics include the sparse missing-Gender
separation limitation. Technical execution and committed-clone evidence are
recorded through `docs/cp2-submission-readiness.md`.


## Checkpoint 3: frozen-model external evaluation

Supply the official `data/set-a/`, `data/set-b/`, `data/set-c/` and
`data/Outcomes-a.txt`, `data/Outcomes-b.txt`, `data/Outcomes-c.txt`, then run:

```sh
pixi run --locked checkpoint3
```

No CP2 training/render command is required. `artifacts/cp2_final_model.rds`
is the exact frozen CP2 elastic-net model plus fitted preprocessing (its manifest
records provenance and hashes); `artifacts/cp2-cv-summary.csv` is only the aggregate
CP2 comparison. CP3 applies saved Set A state, not new B/C imputation or tuning.
It writes `output/checkpoint3.html` and ignored CP3 prediction/diagnostic files.
The first complete task took 125.8 seconds (about 2.1 minutes), including data
construction, 2,000-replicate stratified bootstrap analyses and rendering, on the
same Darwin arm64 development machine. Final and clean-snapshot timings are in
`docs/cp3-verification.md`; other platforms are not claimed as executed.

The external adapter audits unlabeled source observations without guessing their
variable, and resolves duplicate time-zero descriptors by source order while
preserving every original time-window summary. Raw inputs and CP2 files are
unchanged. The prespecified review threshold is 20%, DCA range 5%–40%; SOFA's
separate logistic risk mapping is trained on A only. Calibration regressions
are diagnostic and never update the frozen prediction rule. Read the report's
limitations before interpreting risk, subgroup differences or clinical usefulness.

Checks: `pixi run --locked Rscript tests/test-cp3-data.R`,
`pixi run --locked Rscript tests/test-cp3-metrics.R`,
`pixi run --locked Rscript tests/test-cp3-analysis.R`,
`pixi run --locked python tests/test-cp3-report.py`, and
`pixi run --locked python tests/audit-cp3-frozen.py`.
