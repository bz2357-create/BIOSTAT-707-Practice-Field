# Checkpoint 2 historical verification record

This records automated implementation checks from October 10, 2026, before the
V0.3 report revisions and committed-clone verification. It documents technical
evidence only. Current execution evidence is described in
[cp2-submission-readiness.md](cp2-submission-readiness.md).

## Starting state and primary requirements

- Repository root was confirmed with `git rev-parse --show-toplevel`; origin is
  `https://github.com/bz2357-create/BIOSTAT-707-Practice-Field.git`.
- Branch `main`, HEAD `4ea49b6ee6417adc0197505820c4d7b991700ca1`; initial Git status clean.
  No applicable repository AGENTS.md was found in the project/workspace scan.
- Exactly 4,000 `data/set-a/` patient files and `data/Outcomes-a.txt` were present.
- Public course pages were read before implementation. The web connector could
  not fetch them; `curl -L --fail --max-time 30` succeeded with network access.
  Checklist remained DRAFT, published 2026-10-08 08:10; syllabus remained
  published 2026-10-08 11:24. No substantive requirement discrepancy was found.
  The checklist explicitly requests exceptions for both future report names;
  CP3's HTML exception is reserved but no task/code/report is created for it.
- Primary dataset documentation verified Gender/ICUType coding and measurement
  units. Installed package help verified glmnet, ranger, GAM and k.check APIs.

## Environment and execution decisions

The checkout path contains a colon, which split the in-place conda bin directory
in PATH. An initial `pixi run --locked Rscript` consequently used system R 4.3.2
rather than the locked environment. This was detected before fitting models.
`pixi install --locked --config-file pixi-config.toml` and
`pixi config set --local detached-environments true` enabled the already-planned
detached environment; no global Pixi setting was changed or old environment deleted.
The report asserts that R.home() and every library path belong to CONDA_PREFIX.

`pixi add r-tidyverse r-glmnet r-mgcv r-ranger r-proc` succeeded, retaining all four
platforms. Resolved R is 4.5.3; glmnet 5.0, mgcv 1.9.4, ranger 0.18.0, pROC 1.19.1,
tidyverse 2.0.0. glmnet 5's per-call control API is used. Forests use one thread;
BLAS/OpenMP limits are set in activation for reproducible render execution.
Pixi emits a host archspec warning (m1 in lockfile versus x86_64 reported by the
launcher), but the resolved ARM R binaries execute; this warning is preserved in
logs. The original local in-place environment also causes a harmless detached-
environment warning. No platform was removed to evade solving.

The training-only smoke command `pixi run --locked Rscript tests/cp2-smoke.R`
exited 0: 500 trees, third-of-p mtry, node size 5, 2,132 training stays and 442
encoded columns took 10.605 seconds. It examined no outer-assessment performance;
the frozen 500-tree, six-setting forest grid was retained.

## Tests executed during development

- `pixi run --locked Rscript tests/test-cp2.R`: first failed because CP2
  preprocessing was absent; passed after implementation. A logical all-NA test
  fixture was corrected to numeric NA to match the declared measurement schema.
- `pixi run --locked Rscript tests/test-cp2-models.R`: first failed because model
  helpers were absent; passed after implementation. An added real forest-tuning
  fixture exposed a double-versus-integer mtry return mismatch; the return type
  was corrected and the test then passed.
- `pixi run --locked Rscript tests/test-cp2-results.R`: first failed because
  comparison helpers were absent; later exited 0.
- `pixi run --locked Rscript tests/test-cp2-plots.R`: first failed because effect
  helpers were absent; later exited 0. This includes data/preprocessing and real
  estimator/tuning fixtures.
- `pixi run --locked Rscript tests/test-loader.R`: exited 0, including all CP1
  loader, Round 2, Round 3 and Round 4 tests, without rendering CP1.
- Artifact integration was first run before artifacts existed and failed at
  the required-file check, as expected. Final post-render evidence is recorded
  below after execution.

A separate read-only Codex reviewer found no critical leakage/event-coding defect.
It caught an artifact test that required 54 preprocessing states for every winner;
valid elastic-net/GAM winners have 50, with four additional states only for a forest
winner. The count was corrected to follow the selected family. Reviewer fixture
runs also exited 0. This is an additional AI review, not independent human review.

## Evidence by checklist section

| Requirement | Report/code/output evidence | Status |
|---|---|---|
| 2.1 One stay/row, complete one-to-one death join, dimensions/deaths, timing and cleaning | Report 2.1; CP1 validation reused in R/cp2-data.R; cp2_modeling_table.csv, cp2_cleaning.csv, cp2_source_summary.csv | Reconstruction and fixture/integration checks executed |
| 2.2 Eligible predictor list, ICUType/Gender categorical, missingness counts, exact drops | Report 2.2; cp2_predictors(), cp2_dictionary(), training preprocessing; cp2_predictor_dictionary.csv, cp2_dropped_columns.csv and inner state audit | Executed; final artifact audit exited 0 |
| 2.3 Shared five stratified stay folds; nested train-only preprocessing; fixed-direction per-fold AUROC/mean/SD | Report 2.3; cp2_folds(), explicit inner loops, cp2_auc(); outer/inner fold files and preprocessing audit | Executed; 50 stored training-only states verified |
| 2.4 Fixed-alpha elastic net, inner lambda CV, comparable coefficient plot and all retained/stability evidence | Report 2.4; cp2_enet_path(), cp2_tune_enet(); coefficient and stability tables/plots | Executed; coefficients/stability verified and plotted |
| 2.5 Prespecified 17-variable GAM, REML, three original-unit centered effects/bands/rugs and actual-shape interpretation | Report 2.5; GAM branch, cp2_effect_data(); effect curves/support, basis and fallback files | Executed; curves/reload verified and visually reviewed by Codex |
| 2.6 Forest grid, correct mortality probability, inner tuning, imputation and common folds | Report 2.6; ranger branch and explicit tuning loop; tuning CSV | Estimator/tuning fixtures and timing smoke executed |
| 2.7 Five-method common-cohort table/ROC, variability, explained choice, full refit, saved preprocessing/OOF | Report 2.7; cp2_compare()/cp2_run()/cp2_predict(); performance, model RDS and OOF CSV | Executed; stored metrics and predictor-only reload verified |
| Common AI disclosure, formatted interpreted report, locked one-command execution | Report starts with disclosure; Pixi task, .gitignore, README | Exact final task exited 0; embedded HTML inspected |

## Quarto output-preservation incident and repair

A layout-preview invocation with `--output-dir output` unexpectedly removed the
preexisting output directory. This was an agent error; the user was told when it
was discovered. Installed Quarto 1.9.38 sets `forceClean` for a standalone render
with `--output-dir`, then recursively clears that directory before execution.
A tiny reproduction observed a preexisting sentinel absent at the first R chunk.
The root preview invocation caused the loss; a separate nested-source reproduction
did not reproduce that deletion.

The submitted CP1 HTML was restored byte-for-byte with `git show HEAD`, from the
initial clean commit. An isolated pristine local clone of that commit, supplied
only the permitted clinical inputs, successfully ran `pixi run --locked checkpoint1`
(exit 0) to regenerate 22 supporting CSVs/figures. The long CSV SHA-256 is
`5b318e5d7155bc48a401db4f5e926ee10f79f1e99948fc0305d3aa6976a36690`; wide is
`2e1642737a4725784e1aff45161b68f1f383757781cd50f3f60a2d6f40f14cb6`, both matching
CP1's recorded golden hashes. Its newly rendered HTML was not copied over the
submitted original. Other supporting outputs were regenerated, rather than
proven identical to the original complete baseline manifest (that manifest was
also removed). CP1 source and the human-review checklist were unchanged.
Recovered outputs were backed up outside the main output directory before further
verification. All 4,000 raw-file SHA-256 hashes and the outcome-file SHA-256 matched
CP1 provenance after this work.

A minimal genuine default project in `_quarto.yml` prevents the standalone cleanup
branch while retaining both instructor task strings. A regression test creates
preexisting CP1 HTML/CSV fixtures, executes the exact Quarto command, and checks
that both fixtures and newly created artifacts survive. It passed with both
checkpoint sources present.

An additional colon-path fixture reproduced Dart Sass treating an absolute
filename as a `source:destination` argument. `theme: none` and `minimal: true`
still failed because this Quarto release unconditionally adds a Sass brand bundle;
those trial formatting changes were removed. The first activation attempt mistakenly preserved the package-provided
`QUARTO_DART_SASS` default, so the main render completed all fitting but failed
at theme compilation. Inspecting the actual environment exposed this; activation
now replaces that default on colon-containing POSIX paths, and the fixture checks
the actual environment value before rendering. The retained default theme uses
`scripts/quarto-sass.py` through POSIX Pixi activation only when the checkout path
contains a colon. It converts Sass's first two positional paths to relative paths
and executes the locked Sass binary; it changes no model input or fitted result.
The actual report-header/configuration fixture in a colon-containing temporary
path then exited 0, preserved sentinels, and generated embedded HTML. This wiring
uses platform-specific activation scripts, as documented in the
[Pixi environment reference](https://pixi.prefix.dev/latest/workspace/environment/).
Windows has no added POSIX activation script. Other platform executions were not
performed on this macOS host.

## Final execution evidence

The exact `pixi run --locked checkpoint2` command exited 0 in the exported
working-tree snapshot, which initially contained no generated CP1/CP2 CSVs or
model files. Its only clinical inputs were symlinks to `data/set-a/` and
`data/Outcomes-a.txt`. A copied submitted CP1 HTML and a preservation sentinel
both survived the complete render byte-for-byte. This was an exported snapshot,
not a committed fresh clone. Source report/R files matched the working tree at that execution. This run
predated the final CSV-precision/canonical-evaluation and activation fixes; the
final main run below executes those fixes.
Measured pipeline time was 585.894 seconds (9.765 minutes); an earlier development
pipeline took 584.913 seconds. These two earlier executions gave the same five-method fold
AUROCs before the export-precision correction. Environment installation and development/debugging time are separate.

The completed HTML was inspected with the in-app browser at a 1280-pixel-wide
viewport. The opening disclosure, coefficient labels and main comparison table
were readable, with no horizontal page overflow. All seven figure images were
loaded/embedded, all ten TOC links had valid targets, and no external stylesheet
or script was required. TOC navigation was exercised; supporting PNGs were also
visually inspected, including coefficient stability, central/full-range
Temperature smooths and the five-method ROC plot. These are AI-assisted checks.

The artifact audit initially failed on `identical()` comparing a serialized
`data.table` self-reference pointer in the drop-reason table. Diagnosis showed all
fitted values equal; the test now converts that table to a plain data frame and
still requires exact equality for every preprocessing value and attribute.
A later ROC assertion also had a data.table scoping error: its loop variable
matched the column name and selected all methods. The loop was corrected to use
a distinct variable name. The audit verified all training-only states, then found a substantive export
precision issue: default `fwrite` precision merged adjacent forest probability
values, shifting mean AUROC after CSV reload from 0.8322203033 to about 0.8322277.
The final export uses 17 significant digits for model probabilities. Both fast
and standard R numeric parsers can still shift some entries by one ULP; the
reloaded 17-digit CSV gives forest mean AUROC 0.8322232588. The report now computes
its comparison and ROC data from the newly written CSV, making the handed-off
representation canonical. No tuning grid or fitted-model parameter changed.
An adjacent-double roundtrip fixture failed before the export helper existed,
then passed for its representative adjacent-double fixture. The complete final
main-checkout render and artifact checks below both passed.

Fresh-process saved-model/GAM-effect reload test exited 0. No R modeling warnings
were emitted; basis diagnostics remain a separate limitation: low k-check p-values
occurred for outer BUN (fold 1) and lactate (folds 3/5), without expanding bases
or revising the frozen formula. Full-fit smooth p-values were all above 0.05;
Temperature EDF 3.39 of 4 possible degrees warrants caution. No clinical utility,
causality or statistical-significance claim is made.

The historical snapshot above was not a committed CP2 clone.



## Executed results

Reconstructed modeling table: 4,000 stays × 455 columns, 554 deaths (13.85%).
CP1 hard-invalid exclusions: 33 records; CP2 zero-weight changes: 184 records;
zero-height changes: 0. Broad candidate count: 449, with 442 retained encoded
columns after dummy coding and ten constant MechVent value-summary removals.
No full-fit candidate was dropped for 100% missingness. GAM source count: 17,
encoded input count: 20, fitted coefficient/basis count: 54.

The five-method comparison uses 3,733 stays and 520 deaths in every method.
The excluded 267 stays include 34 deaths; all 4,000 learned-model OOF rows remain.
SAPS-I availability is 3,810, SOFA availability 3,856.

| Method | Fold 1 | Fold 2 | Fold 3 | Fold 4 | Fold 5 | Mean | Sample SD |
|---|---:|---:|---:|---:|---:|---:|---:|
| Elastic net | 0.8472 | 0.8349 | 0.8288 | 0.8491 | 0.8349 | 0.8390 | 0.0088 |
| GAM | 0.8211 | 0.8011 | 0.8184 | 0.8319 | 0.8235 | 0.8192 | 0.0113 |
| Random forest | 0.8559 | 0.8180 | 0.8341 | 0.8479 | 0.8052 | 0.8322 | 0.0209 |
| SAPS-I | 0.6519 | 0.6605 | 0.6791 | 0.6512 | 0.6096 | 0.6504 | 0.0254 |
| SOFA | 0.6541 | 0.6021 | 0.6410 | 0.6252 | 0.5703 | 0.6185 | 0.0332 |

Selected family: elastic net, alpha 0.5, final all-set-a three-fold-CV
lambda 0.0221221629107045. All five outer fits selected 0.0161026202756094; no
lambda boundary selection occurred. Full fit retained 51 nonzero coefficients
at tolerance 1e-8; 27 features were retained in all five outer fits, 140 in at
least one. Every outer forest selected 500 trees, mtry 21 (sqrt rule), node size 5.
The elastic-net lead over forest is approximately 0.00674, small beside fold variation; the
choice also considers computational simplicity and coefficient interpretation.
Neither external validation nor clinical usefulness is established.

The saved bundle/fixture reload agrees within 1e-12 (observed error zero). Bundle
metadata includes preprocessing, feature construction, event mapping, package
versions and fixed seeds/fold references. It consumes constructed predictors,
with no outcome or preprocessing refit. This handoff has not been applied to any
other dataset.

## Final main-checkout command and audit

The final `pixi run --locked checkpoint2` exited **0** and created
`output/checkpoint2.html` with the final sources/configuration. The measured
analysis pipeline elapsed time was **570.293 seconds (9.505 minutes)**, from the
actual `output/cp2_runtime.txt`: R 4.5.3, Darwin 25.6.0 arm64, eight logical cores,
one ranger/BLAS thread. This measures analysis execution, not environment
installation, report packaging or development/debugging time. Its full log is
`output/cp2_main_render.log`; the prior failed Sass run is retained separately.

| Final validation command | Exit | Evidence |
|---|---:|---|
| `pixi run --locked checkpoint2` | 0 | Full raw-input reconstruction, tuning/fitting and embedded HTML; `cp2_main_render.log` |
| `pixi run --locked Rscript tests/test-cp2-plots.R` | 0 | Data/preprocessing and real estimator/tuning/plot fixtures; `cp2_final_fixtures.log` |
| `pixi run --locked Rscript tests/test-cp2-results.R` | 0 | Fixed direction, comparison and adjacent-double export fixtures; `cp2_final_comparison_fixtures.log` |
| `pixi run --locked Rscript tests/test-cp2-artifacts.R` | 0 | Fresh final outputs: 4,000 OOF stays, 50 exactly verified training-only states, stored metrics/ROC/GAM curves; `cp2_artifact_verification.log` |
| `pixi run --locked Rscript tests/test-cp2-reload.R` | 0 | Fresh R process, predictor-only saved-model and GAM effect extraction; `cp2_fresh_reload_final.log` |
| `pixi run --locked python tests/test-cp2-render-safety.py` | 0 | Actual activation/header/config, colon path and existing-output preservation; `cp2_colon_render_safety.log` |
| `pixi run --locked Rscript tests/test-loader.R` | 0 | CP1 loader and Round 2–4 regression/integration; `cp2_cp1_regression.log` |
| `git diff --check` | 0 | No whitespace errors |

The final artifact audit reproduced preprocessing directly from each state's
saved training IDs and required exact fitted values/attributes. The bundle reload
error was zero on its saved predictor-only fixture (tolerance 1e-12). All metrics
and plotted data aligned with the saved OOF CSV. No R modeling warnings occurred;
the detached-environment/archspec messages and GAM basis limitations above remain
disclosed. This was a macOS runtime verification; other locked platforms were not
executed.

The browser was refreshed with the final main HTML. All seven figures were
loaded and embedded, all ten TOC targets resolved, there were no external scripts
or stylesheets, and no horizontal page overflow was observed. The final disclosure
and comparison were read; earlier 1280-pixel table/figure layout checks used the
same displayed rounded values and figure layouts.

All 23 recovered CP1 output hashes still matched the recovery manifest. Eleven
CP1 source/test/checklist/HTML files were byte-identical to the initial HEAD.
The recovery distinction above still applies: supporting files were regenerated,
not proven identical to their lost complete pre-incident baseline. The final Git
status consists of local CP2 additions and README/environment/ignore changes;
branch `main` and HEAD remain unchanged. No commit, push, PR or submission occurred.
The historical record ends before the V0.3 candidate-commit check.

## Final QA follow-up V0.2

The bounded follow-up is recorded in [cp2-final-qa.md](cp2-final-qa.md). Fresh
fixture/artifact/reload/CP1 and exact-partition checks passed. The three extreme
GAM OOF errors were reproduced and traced to sparse missing-Gender parametric
quasi-separation; frozen specifications, OOF/model artifacts and report remain
unchanged. The scientific qualification and historical verification limits are recorded
there. This follow-up preserves the CP1 recovery caveat above.
