# Checkpoint 2 final QA — V0.2

Date: October 10, 2026. Historical automated diagnostic checks before the V0.3
report edits. Scope was CP2 only; no held-out clinical input, new tuning search,
model-family replacement, commit, push, PR or submission was performed in V0.2.
Current execution evidence is described in
[cp2-submission-readiness.md](cp2-submission-readiness.md).

## A. Technical findings

The focused modeling/artifact checks passed, with a material GAM stability
limitation below. Three extreme GAM errors were reproducible sparse-category
quasi-separation, with no established feature-construction, leakage or
event-orientation bug. The frozen comparison was retained. This historical
record did not include a committed CP2 fresh-clone execution.

## B. Official checklist 2.1–2.7

The current [official checklist](https://steverozen.github.io/biostat707_2026/checkpoint2-3-checklist.html)
was fetched on this QA run. It is still DRAFT, published 2026-10-08 08:10; no
substantive CP2 requirement difference was found. The CP2/common-requirement
excerpt is saved in `output/cp2_qa_official_checklist.txt`. The web connector failed;
`curl -L --fail --max-time 30` succeeded after allowing network access.

PASS below means the specific modeling/report requirement was verified, with
scientific qualifications retained. V0.2 did not test a committed CP2 clone.

| Section | Status | Exact evidence |
|---|---|---|
| 2.1 Modeling table | PASS | `checkpoint2.qmd` section 2.1 / HTML Tables 1–2; `R/cp2-data.R` `cp2_data()`; `R/build-wide.R` `validate_wide()`; `output/cp2_modeling_table.csv`, `cp2_cleaning.csv`; fresh CP1/artifact tests |
| 2.2 Predictors | PASS | HTML Tables 3–6, expanded dictionary/drop list; `R/cp2-data.R` allowlist/dictionary and `R/cp2-preprocess.R`; `output/cp2_predictor_dictionary.csv` (450 rows including GAM-only indicator), `cp2_dropped_columns.csv` |
| 2.3 CV/preprocessing | PASS | `R/cp2-run.R` outer/inner loops; `R/cp2-preprocess.R`; `output/cp2_outer_folds.csv`, `cp2_inner_folds.csv`, `cp2_preprocessing_audit.rds`; fresh exact-assignment audit of all 50 states |
| 2.4 Regularized logistic | PASS | `R/cp2-models.R` explicit inner lambda tuning; HTML Tables 8–9 and Figures 1–2; `output/cp2_coefficients.csv`, `cp2_selection_stability.csv`, `cp2_tuning_enet.csv` |
| 2.5 GAM | PASS, stability qualification | `R/cp2-models.R` fixed 17-source-variable GAM, REML/k=5; HTML Tables 10–12 and Figures 3–6; `output/cp2_gam_effect_curves.csv`, `cp2_gam_diagnostics.csv`; new three-case diagnostic below |
| 2.6 Tree ensemble | PASS | `R/cp2-models.R` forest fit/tuning; HTML Table 13 / section 2.6; `output/cp2_tuning_forest.csv`, `cp2_selected_hyperparameters.csv`; real-estimator fixtures |
| 2.7 Comparison/final handoff | PASS | HTML Tables 14–19 and Figure 7; `R/cp2-run.R` comparison/selection/refit; `output/cp2_performance.csv`, `cp2_oof_predictions.csv`, `cp2_final_model.rds`; fresh artifact/reload checks |

Confirmed dimensions: 4,000 stays × 455 columns, 554 deaths (13.85%); 449 broad
raw candidates, 442 retained encoded columns. CP2 converts 184 zero-weight
records and zero zero-height records to missing. Ten constant MechVent value
summaries are dropped; useful counts are retained. The GAM has 17 source inputs,
20 encoded columns and 54 fitted coefficients/basis coefficients.

All 4,000 OOF rows remain. The five-method common cohort is 3,733 stays / 520
deaths; 267 stays / 34 deaths lack at least one benchmark. Fresh recomputation
confirms rounded fold means/SD: elastic net .8390/.0088, GAM .8192/.0113,
forest .8322/.0209, SAPS-I .6504/.0254, SOFA .6185/.0332. No parser/tie-handling
or export changes were made in this QA.

## C. Implementation audit

This QA read the actual helpers, report, configuration, tests and stored states,
rather than relying on the previous prose assertions.

- `cp2_data()` reads only `data/set-a/` and `data/Outcomes-a.txt`; loader preserves
  source strings, maps -1, validates IDs/timing. CP1 audit/build functions are
  unchanged. CP2 zero rules operate on a copy before aggregation. IDs are sorted,
  the outcome join uses explicit matching, and population/schema checks fail on
  conflicting or malformed records. All 4,001 permitted input hashes match CP1
  provenance; no held-out file was opened.
- The positive 449-column allowlist excludes both target names, RecordID,
  Length_of_stay, Survival, SAPS-I/SAPS_I and SOFA. The GAM-only documented
  ventilation indicator is deterministic within stay. Benchmarks are separate
  evaluation columns; their -1 codes are mapped to missing, not imputed/calibrated.
- Stratified outer folds use seed 7072026 and sorted IDs. Shared three-fold inner
  assignments are generated only in each outer training pool; all-set-a tuning
  uses seed 7072926. Each family's loop slices the training rows before fitting.
- Numeric medians, observed category levels/missing fallback/reference dummies,
  all-missing/constant removals and elastic-net means/sample SDs are fitted on
  that slice. GAM log1p count transforms are fixed. Assessment values cannot
  change fitted states. Fresh fixtures test assessment perturbations and
  category/schema/row preservation. The artifact audit rebuilds all 50 saved
  states and compares exact preprocessing values. The complementary partition
  audit matches each saved training AND assessment ID set to the corresponding
  persisted outer/inner assignment, including final-refit inner folds.
- Elastic net's alpha .5 and 30-value lambda path remain frozen; `standardize=FALSE`
  follows explicit train-only scaling. Forest uses the frozen 500-tree grid,
  train-only tuning/imputation and death column `1`. The actual broad p=442 makes
  sqrt mtry smaller than third mtry, consistent with the implemented tie rule.
- Rank AUROC fixes larger score = death; pROC fixes levels 0:1 and direction `<`.
  Common-cohort and all-stay summaries remain separate. Selected elastic net uses
  final all-set-a inner tuning (lambda .0221221629107045), not averaged penalties.
  The bundle's predictor-only reload does not refit preprocessing or need labels.
- No genuine CP2 implementation defect was found or fixed. The new diagnostic
  script initially used a data.table sort expression unsupported by `setorder`;
  this QA-script error was corrected to `order()`. A diagnostic-only standard-error
  lookup on an unnamed covariance diagonal was replaced by the named GAM summary
  table. Neither correction changed the analysis helpers, models or report.

Unverified assumptions: source clinical measurements/outcomes are treated under
the frozen cleaning rules; this is not chart adjudication. Clinical explanations
are predictive interpretations. Other locked platforms were not executed. V0.2
did not test a fresh clone of a committed CP2 candidate.

## D. Three extreme GAM cases (no patient IDs in this narrative)

Only the two relevant frozen GAM outer fits were reconstructed for diagnosis:
folds 1 and 3, using identical training IDs, preprocessing, formula, k=5, REML and
seeds. This is a reproduction of the existing fits, not a tuning experiment.
Their preprocessing matches saved state exactly, and their predictions across
all assessment stays match the existing OOF to maximum absolute error
1.11022302462516e-16 (required tolerance 1e-12). Contribution sums plus the
intercept reproduce the link-scale prediction within 1e-8.

| Case | Observed outcome | Fold | Stored GAM probability | Link prediction | Dominant term |
|---|---|---:|---:|---:|---|
| A | Death | 1 | 2.22044604925031e-16 | -55.0123 | `Gender__missing`: -56.4913 |
| B | Survivor | 3 | 0.99999999999999978 | 52.0631 | `Gender__missing`: +55.5220 |
| C | Survivor | 3 | 0.99999999999999978 | 52.8877 | `Gender__missing`: +55.5220 |

The table uses the original 17-digit OOF strings; the numeric diagnostic summary
CSV rounds the near-one values for display. Exact strings are also saved in
`output/cp2_qa_extreme_probability_strings.csv`.

All three source records have Gender = -1, consistently mapped to missing. The
encoded missing level is defined from training observations, not assessment.
In fold 1, the two training records with missing Gender are both survivors. In
fold 3, the sole training record with missing Gender is a death. The unpenalized
parametric missing-category coefficient has no mixed-outcome support in these
training slices, producing **quasi-complete separation and numerically saturated
probabilities**. Its estimated SE is approximately 4.75e7 in fold 1 and 6.71e7 in
fold 3, further indicating that a finite converged coefficient is not a stable
scientific effect. No inferential claim is made from those SEs. Both fits passed
the existing convergence checks; such checks alone do not exclude separation.

Case A has two missing source predictors (Gender and respiratory-rate mean,
with respiratory rate imputed at 19.25). Case B has seven missing inputs; its
six numeric medians are HR 86.0545, temperature 37.05, MAP 79.5492, respiratory
rate 19.1981, GCS 13 and lactate 1.4. Case C has two missing inputs (Gender and
lactate, imputed at 1.4). Numeric values came only from the respective outer
training partition. All 17 source values, applied design values and supported
training min/max/1st–99th percentiles are recorded in the feature evidence CSV.

Only A has a raw input beyond its training min/max: lactate count 15 versus
training maximum 14. This is a log1p linear count term and is not the dominant
contribution. B/C have no source inputs outside training min/max. The extreme
errors are principally **rare categorical support/separation**, not temperature
smooth extrapolation or a reversed event column. Raw source rows, missingness,
medians and term decomposition were inspected; no new data deletion rule was
introduced. Saturation at a floating-point probability endpoint must not be
read as clinical certainty.

Local detailed evidence (IDs only in the ignored index/source files):
`output/cp2_qa_extreme_case_index.csv`, `cp2_qa_extreme_source_rows.csv`,
`cp2_qa_extreme_features.csv`, `cp2_qa_extreme_contributions.csv`,
`cp2_qa_extreme_summary.csv`, `cp2_qa_gender_training_support.csv`,
`cp2_qa_extremes.log`. Reproduction script: `tests/cp2-qa-extremes.R`.

The V0.3 report now includes the sparse-category separation qualification
immediately after its GAM diagnostics. The frozen specification and numerical
artifacts are retained; no model repair, calibration or CP3 analysis is included.

## E. Reader review, changes and executed commands

The existing HTML was served read-only on localhost and inspected in the in-app
browser. All seven actual figures were inspected: readable coefficient/stability
labels, original-unit Age/HR/temperature plots with centered log-odds labels,
pointwise bands/rugs, the full temperature tail, and the five-curve ROC legend.
All six details controls were expanded. The DOM has sequential Tables 1–21 and
Figures 1–7; dictionary has 450 rows, drop list 110 fit-specific rows, complete
coefficient table 442 rows, GAM diagnostic table 66 rows. Ten TOC targets resolve;
all images are loaded/embedded, no external script/stylesheets, no page-level
horizontal overflow. Wide support/diagnostic tables can require horizontal
scrolling in a narrow window. The main comparison and its denominators are clear.

The V0.3 report adds first-use definitions for CCU/CSRU/MICU/SICU,
ALP/ALT/AST and SD without an additional table. Scientific cautions remain:
no causal, clinical-utility or statistically significant superiority claim;
the elastic-net/forest difference is small relative to fold variability, and
Temperature interpretations remain restricted to supported central shapes.
The opening AI-use statement names ChatGPT and OpenAI Codex, the actual checks,
implementation benefits, debugging and output-recovery drawbacks, and GAM
instability. Detailed recovery provenance remains in the historical record.

| Command/check during this QA | Actual exit/status | Log/evidence |
|---|---|---|
| `pixi run --locked python tests/test-cp2-render-safety.py` | 1 in sandbox; same command 0 with existing-cache access | `output/cp2_qa_preservation.log`, `cp2_qa_preservation_retry.log` |
| `pixi run --locked Rscript tests/cp2-qa-extremes.R` | Initial diagnostic-script sort error 1; corrected final run 0 | `output/cp2_qa_extremes_initial_failure.log`, `cp2_qa_extremes.log` |
| `pixi run --locked Rscript tests/test-cp2-plots.R` | 0 | `output/cp2_qa_plots.log`; includes data/preprocessing and real estimator/tuning fixtures |
| `pixi run --locked Rscript tests/test-cp2-results.R` | 0 | `output/cp2_qa_results.log` |
| `pixi run --locked Rscript tests/test-cp2-artifacts.R` | 0 | `output/cp2_qa_artifacts.log`; all 50 exact training-only preprocessing states and metrics/curves |
| `pixi run --locked Rscript tests/test-cp2-reload.R` | 0 | `output/cp2_qa_reload.log`; fresh-process predictor-only saved handoff |
| `pixi run --locked Rscript tests/test-loader.R` | 0 | `output/cp2_qa_cp1.log`; CP1 loader and Round 2–4 |
| `pixi run --locked Rscript output/cp2_qa_partition_audit.R` | 0 | `output/cp2_qa_partition_audit.log`; exact outer/inner membership for all 50 states |
| Locked R/library-prefix/package check | 0 | `output/cp2_qa_environment.log`; command retained in `cp2_qa_commands.json` |
| SHA-256 inventory/input/CP1 preservation check | PASS | `output/cp2_qa_inventory.csv`, `cp2_qa_integrity.json` |
| `git diff --check` | 0 | Final QA validation |

The final frozen-GAM diagnostic took 24.778 seconds, as actually logged. This is
not a new complete-pipeline timing. No full `pixi run --locked checkpoint2` was
rerun in this QA because no modeling/report/config source or HTML changed.
The unchanged HTML's previous full exact-task run exited 0, with analysis time
570.293 seconds (9.505 minutes), matching README and `output/cp2_runtime.txt`;
`output/cp2_main_render.log` ends in successful creation. The already established
input-only exported snapshot test is historical evidence, not a committed clone.

Locked commands validated the unchanged manifest/lock and package versions;
R.home() and every library directory are inside CONDA_PREFIX. The checkout's
local detached-environment configuration remains active; no global setting or
personal R library was used. Four lock platforms remain; only macOS execution
was verified. Existing Pixi detached-environment/archspec warnings remain.
The isolated preservation fixture's initial Sass cache database failure was a
sandbox-write constraint, resolved by the same command with cache access; the
main output tree was never a preview target.

New files: `docs/cp2-final-qa.md`, `tests/cp2-qa-extremes.R`, and ignored
`output/cp2_qa_*` diagnostic/log evidence. `docs/cp2-verification.md` adds a pointer
here. All 87 baseline source/config/artifact hashes were unchanged before the
QA-note pointer. Original model/OOF/report hashes, specifications, folds, tuning
and selected family remain unchanged. No raw data, model or OOF is staged or
tracked; only HTML is permitted among CP2 generated modeling outputs.

**CP1 preservation:** eleven original source/test/checklist/committed-HTML files
remain byte-identical to initial HEAD. All 23 recovered output hashes still match
the recovery manifest. The prior caveat is preserved: the submitted HTML was
restored exactly from Git; 22 supporting files were regenerated, with golden
long/wide hashes checked. Their lost complete original baseline cannot be claimed
byte-for-byte restored. The original CP1 human-review checklist was not edited.

## F. Historical scope boundary

V0.2 ended on branch `main`, HEAD
`4ea49b6ee6417adc0197505820c4d7b991700ca1`, with local CP2 work. No commit,
push, PR, submission or held-out data access occurred in that QA. V0.3 separately
authorizes the local candidate commit and its fresh-clone test. The current
technical execution record is `docs/cp2-submission-readiness.md`.
