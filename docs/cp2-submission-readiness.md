# Checkpoint 2 technical execution record — V0.3

Date: October 10, 2026. This record describes automated technical verification.
The local candidate commit and committed fresh-clone test are authorized by the
V0.3 brief. No push, PR, Canvas submission or Checkpoint 3 work is included.
Machine-specific final command statuses, times, candidate SHA, exact committed
file list, clone location and integrity results are retained locally in
`output/cp2_v03_closeout.json` and `output/cp2_v03_closeout.md`. Those ignored
records are separate from the scientific report and avoid embedding a commit's
own identity in its tracked contents.

## Scope and changes

The report keeps the author byline and its 21 tables and seven figures. Its
opening AI-use statement identifies ChatGPT planning and OpenAI Codex coding,
debugging, execution, automated checks, figure inspection and explanatory prose.
It records implementation benefits and the output-removal/recovery drawback,
without asserting human verification. The report uses a scientific
Reproducibility heading and a substantive elastic-net decision, retaining its
small lead over forest and the model-selection optimism limitation.

A paragraph immediately after the GAM diagnostics explains three incorrect
extreme OOF probabilities, the unpenalized missing-Gender dummy with one or two
same-outcome training cases, quasi-complete separation despite convergence, and
unstable individual risks. It retains the frozen models and comparison. No
individual IDs or source-case debug rows appear in the report. First-use
expansions cover ICU categories, liver enzymes, other clinical source labels,
GAM, SD and ROC; no additional table is introduced.

CP2 support documents retain dated technical evidence and the CP1 recovery
provenance. The exact training/assessment membership audit is now a repository
test, `tests/test-cp2-partitions.R`. The new rendered-report test verifies the
actual HTML's disclosure, caveat, glossary, navigation, numbered tables and
embedded figures. The five CP2 analysis helpers, model specifications, grids,
cleaning, preprocessing, folds and selection rule are unchanged from V0.2.

## Official checklist mapping

The [official course checklist](https://steverozen.github.io/biostat707_2026/checkpoint2-3-checklist.html)
was fetched again for V0.3; its extracted text is identical to the V0.2 copy
(DRAFT, published 2026-10-08 08:10). The report mirrors sections 2.1–2.7.

| Requirement | Concrete evidence |
|---|---|
| 2.1 Modeling table/cleaning | `checkpoint2.qmd` 2.1, Tables 1–2; `R/cp2-data.R`; 4,000 stays, 554 deaths, 48-hour availability, 184 zero-weight records; CP1/artifact tests |
| 2.2 Predictors | 2.2, Tables 3–6; 449-column allowlist, categorical encoding, measurement counts, training-only exact drops; artifact test |
| 2.3 CV/preprocessing | 2.3, Table 7; shared five outer folds/three inner folds, 50 exact preprocessing states; artifact and partition tests |
| 2.4 Elastic net | 2.4, Tables 8–9, Figures 1–2; fixed alpha, inner lambda tuning, standardized coefficients and selection stability; model/plot tests |
| 2.5 GAM | 2.5, Tables 10–12, Figures 3–6; 17 clinically specified sources, REML/k=5, original-unit centered effects/bands/rugs; curve/reload and frozen-extremes tests; separation limitation |
| 2.6 Forest | 2.6, Table 13; fixed 500-tree grid, training-only imputation/tuning, death-column probability; real-estimator/model fixtures |
| 2.7 Comparison/refit | 2.7, Tables 14–19, Figure 7; common 3,733 stays/520 deaths, five fold AUROCs and means/sample SDs, five-curve ROC; full elastic-net refit, fitted preprocessing, predictor-only reload and OOF CSV |
| Shared report/AI | Opening disclosure, interpreted numbered/formatted tables and figures, acronym definitions, embedded HTML and TOC; rendered-report test and browser inspection |
| Shared locked reproducibility | Exact task in `pixi.toml`, locked four-platform environment, README command/time, HTML ignore exception; main execution and committed fresh-clone execution recorded locally |

The checklist also calls for pushing the final commit. That external publication
is outside the user's authorization; the local verification does not assert it.

## Reproduction and regression commands

Run the output-preservation fixture before the full task. It uses temporary
sentinels and never previews the real output directory. Back up or hash CP1 HTML,
all recovered CP1 outputs and all allowed inputs first. The task needs only
`data/set-a/` and `data/Outcomes-a.txt`; do not render CP1 as a prerequisite.

```sh
pixi run --locked python tests/test-cp2-render-safety.py
pixi run --locked checkpoint2
pixi run --locked Rscript tests/test-cp2-plots.R
pixi run --locked Rscript tests/test-cp2-results.R
pixi run --locked Rscript tests/test-cp2-artifacts.R
pixi run --locked Rscript tests/test-cp2-reload.R
pixi run --locked Rscript tests/test-cp2-partitions.R
pixi run --locked Rscript tests/cp2-qa-extremes.R
pixi run --locked Rscript tests/test-loader.R
pixi run --locked python tests/test-cp2-render-safety.py
pixi run --locked python tests/test-cp2-report.py
git diff --check
```

The plots test includes data/preprocessing and real-estimator/tuning fixtures.
The artifact audit recomputes metrics and curves from the saved OOF CSV and
reconstructs every preprocessing value from saved training IDs. The separate
partition test also checks assessment IDs against persisted outer/inner folds.
Reload is a new R process with a predictor-only fixture, tolerance 1e-12.
The extreme diagnostic reconstructs only the relevant frozen GAM outer fits;
it does not tune, repair or overwrite the analysis outputs. Detailed case IDs
remain in ignored local diagnostic files.

## Committed-clone protocol and integrity

Stage only the explicitly printed CP2 whitelist, inspect staged names and diff,
and make a local reversible commit. A new neutral-path clone must have exactly
that HEAD and only the two allowed clinical input links. Before execution it
contains no generated CP2 CSV/RDS or untracked scripts. Its single grader command
is `pixi run --locked checkpoint2`, with no CP1/preparation render. Recheck the
artifact, reload, partition and rendered-report contracts in that clone. Compare
OOF, numerical artifacts and CP1 HTML with the protected baseline, and inspect
`git status --porcelain`; a changed tracked report requires diagnosis.

The pre-edit OOF SHA-256 is
`6d1126f84f49fc5f9d50878d74a714aaffcf6acb79cdf35efb51de0c36a22b90`.
The original CP1 submitted HTML SHA-256 is
`3fe687485ae9a307fffda293703616e9f07943db712eeb0866b9137458830aa3`.
Eleven original CP1 source/test/checklist/HTML files are protected against the
initial HEAD `4ea49b6ee6417adc0197505820c4d7b991700ca1`; 23 recovered output hashes
are protected separately. All 4,001 allowed input hashes must remain unchanged.
Data, outcome files, models, OOF CSVs and machine logs remain ignored/untracked;
only CP2 HTML is versioned among new generated outputs.

## Scientific and verification limits

The missing-Gender separation and outer GAM basis-check cautions remain. The
elastic-net/forest mean AUROC gap is about 0.0067 and does not establish general
superiority, causal effects, reliable individual risks or clinical usefulness.
Model-family selection uses the outer results, so its reported performance can
still be optimistic. No independent external validation is performed. Only
macOS execution is verified; four platforms remain locked. Existing Pixi
host-architecture/detached-environment notices are retained in logs.

The earlier Quarto standalone preview removed shared generated output. CP1 HTML
was restored exactly from Git; 22 supporting files were regenerated with golden
long/wide hashes checked. The lost complete original supporting-output manifest
prevents claiming all regenerated supporting files equal their pre-incident
versions. The preservation regression and genuine project configuration protect
the recovered outputs; this provenance distinction remains in the report and
historical QA notes.

## V0.3 main-checkout results

The exact locked task exited 0, with 587.717 seconds total wall time and 573.544
seconds measured analysis time. This is close to the README's historical 570.293
seconds, so its laptop timing is not materially revised. Fixture/model/result/plot,
artifact, fresh-process reload, exact-partition, frozen-GAM-extremes, CP1 regression,
pre/post preservation and rendered-report checks all exited 0; `git diff --check`
also exited 0. Detailed command records are in the local V0.3 closeout.

All five analysis-helper hashes, 29 numerical CSVs and all five saved RDS files
match the pre-edit baseline byte-for-byte. OOF has 4,000 unique stays, 554 deaths,
five folds and valid probabilities for every learned model; the common cohort
remains 3,733 stays/520 deaths. All 4,001 allowed inputs, all 11 original CP1 files,
and all 23 recovered CP1 outputs are unchanged. Reload error is zero at tolerance
1e-12; exact training and assessment assignments pass for all 50 stored states.

The actual HTML was read in the in-app browser at 1280 × 720. All seven figures
were inspected, all six details controls expanded, and the opening disclosure,
visible separation paragraph and five-method table were checked. All 21 table
captions and seven figure captions are numbered; ten TOC targets resolve. Images,
scripts and styles are embedded, with no horizontal page overflow. The rendered
contract test also finds no individual Set A ID or prohibited workflow label.
Two initial test assertions incorrectly rejected embedded data-URI resources and
expected an ordinary space in Quarto's figure numbering; the test now accepts
embedded resources and Unicode whitespace while retaining the same contract.
This was a test correction, with no report/model change.

An initial V0.3 task invocation was stopped while finalizing first-use acronym
definitions; the completed full run above used the final report source. One
local-server request for the entire output tree was rejected by automatic
approval review because it would include data-derived/model artifacts. Visual
QA instead served an isolated directory containing only self-contained HTML.

The first staged whitespace check reported 14 trailing-space lines in Quarto's
embedded template/JavaScript. A precise `.gitattributes` rule for CP2 HTML disables
only blank-at-end-of-line checking on that generated file, preserving the exact
render bytes. Other whitespace checks and all source-file checks remain active.
The staged check is rerun under that explicit policy; no renderer or model changed.
