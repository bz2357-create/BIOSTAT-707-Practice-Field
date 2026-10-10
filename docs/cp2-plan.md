# Checkpoint 2 implementation plan

Goal: implement the selected October 10 work brief in the existing R/Quarto/Pixi project, using only set-a and preserving Checkpoint 1.

Architecture: fixed within-stay cleaning/aggregation feeds a positive predictor dictionary. Explicit training-only preprocessing feeds nested CV elastic net and forest plus a prespecified REML GAM; common outer folds feed comparison and saved predictions. Quarto runs everything from allowed raw inputs and describes interpretations from actual results.

Execution: the original implementation followed the supplied October 10, 2026
specification. The subsequent V0.3 pass authorizes a local candidate commit and
committed fresh-clone verification, with frozen analysis. Push, PR, submission,
held-out inputs and CP3 work are outside scope.

- [x] Add tests for CP2 zero handling, predictor eligibility, folds, categorical fallback, training-only imputation/scaling, metric direction, and missing schema errors; observe failure before implementation.
- [x] Implement `R/cp2-data.R` (set-a reconstruction/dictionary), `R/cp2-preprocess.R` (fit/apply preprocessing and folds), and `R/cp2-models.R` (nested tuning, fitting, prediction).
- [x] Test real fitted estimators, lambda/node tie rules, small-support GAM fallback, and probability event extraction before completing model code.
- [x] Implement `R/cp2-run.R` (OOF loop, artifacts, audit, final refits) and `R/cp2-plots.R` (coefficients, stability, GAM bands, ROC).
- [x] Add Pixi packages/task and report exceptions; retain four platforms and CP1 workflow. Use project-local detached environments for this checkout's colon-containing path.
- [x] Write `checkpoint2.qmd`: disclosure first, sections 2.1–2.7, formatted evidence/dictionaries, actual-result interpretation, reproducibility/references.
- [x] Run focused tests and all CP1 tests; run locked CP2 from inputs alone in an exported working snapshot without CP1 generated CSVs. Measure runtime and inspect HTML visually.
- [x] Record verification/checklist and README; verify preserved CP1 hashes, artifact reload, stored metrics and clean diff. The V0.3 technical execution record is in `cp2-submission-readiness.md`.

Review focus: unseen/missing categories must preserve rows; all-missing numeric values must not learn from assessment; one-class folds fail; ventilation documentation is not absence of treatment; saved prediction needs no outcome. Warn/basis diagnostics are retained; no outer-performance-driven revisions.
