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
