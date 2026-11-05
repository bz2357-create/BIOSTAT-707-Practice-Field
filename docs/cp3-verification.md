# Checkpoint 3 verification

Status: **implemented and verified locally; uncommitted and unpublished**.

## Exact execution

- Final `pixi run --locked checkpoint3`: exit 0, 112.52 seconds in original project.
- Fresh exported intended snapshot, same exact command: exit 0, 149.21 seconds.
- Fresh location: `/var/folders/8t/fv7_0vjj73584_1jpsq10tjc0000gn/T/biostat707-cp3-fresh-hy0l7zsa`.
- The snapshot is a clean source export of the intended uncommitted tree, not a claimed new Git commit or remote clone. It contains the packaged frozen model and aggregate CV summary, but no ignored CP2 model or prior CP3 results. A/B/C supplied through a local data symlink.
- All six compared numeric/case output tables are byte-identical between original and fresh executions. Existing CP1/CP2 HTML remained byte-identical in both.
- Actual execution platform: Darwin arm64, R 4.5.3; existing lock platforms are retained but not all executed.
- Report: `output/checkpoint3.html`; 16 formatted tables and six embedded numbered figures; report tests check sections, disclosure, no unresolved errors and no B/C RecordIDs in visible text.

## Preservation and provisioning

Original model and packaged copy SHA-256: `a7d30c2eb219ba3eb80ec55f37acea7014b1aa0ce588de6ade04d28e255b3556`.

Serialized preprocessing MD5: 2be9c70396be7d6bf4cf4b204ea59332.

Whole original RDS is unchanged; saved preprocessing serialization matches the byte-identical packaged copy and is checked before/after prediction. Model content audit found aggregate coefficients/preprocessing/metadata and no patient-row content; no new CP2 training or tuning occurred. The separate SOFA-to-risk logistic mapping uses Set A only. Calibration regressions diagnose B/C outcomes without replacing frozen probabilities.

The original 222-file baseline is checked by `tests/audit-cp3-frozen.py`; README additions and the named Pixi task are authorized shared-document/config changes. `_quarto.yml` differs solely by adding checkpoint3.qmd to its explicit render allowlist; removing that line recovers original bytes. All other protected source and saved output hashes match. CP1/CP2 tasks, reports, fitted model, folds and OOF are unchanged. HEAD stays `ba94fd0b0f9953b21defc593e4273058cb0af124`; no commits, pushes, remote API writes, branch-history reconciliation or Canvas submission.

B/C raw input preservation was verified against all 8,000 downloaded archive members plus outcomes checksums. The 4,000 Set A patient files also match the pre-existing source ZIP. No raw source file was rewritten. Download fingerprints are observed hashes, not claimed publisher-supplied checksums.

## Scientific results

Full-cohort AUROC (2,000 stratified-bootstrap percentile 95% CI):

| Split | Stays/deaths | AUROC | 95% CI |
|---|---|---|---|
| B | 4,000 / 568 | 0.8514 | 0.8356–0.8671 |
| C | 4,000 / 585 | 0.8524 | 0.8371–0.8675 |

B-minus-C difference -0.0010 (95% CI -0.0229 to 0.0207), compatible with sampling variation under the independence assumptions. Matched benchmark-cohort results and archived CP2 CV mean/SD are separately labeled in the report.

Calibration intercepts B 0.0109, C 0.0541 (both intervals cross zero); slopes B 1.3428, C 1.3370 (intervals above one), indicating compressed risks globally. Brier B 0.0925/C 0.0950; scaled Brier B 0.2408/C 0.2388. At fixed 20%, sensitivity B 0.6690/C 0.6256, PPV B 0.4348/C 0.4342, flags per 100 B 21.85/C 21.08, event-1 score B 0.4348/C 0.4342.

DCA uses matched SOFA-available cohorts and the A-only risk mapping; no threshold optimization. No direct clinical deployment recommendation is made. Subgroups include sample/event counts, uncertainty and undefined unknown-sex estimates; no multiplicity-corrected or causal group-effect claim is made.

## Real development findings and corrections

- Data-preparation stage: Python urllib certificate-chain validation failed. Official files were downloaded using system curl with normal TLS verification; TLS was never disabled.
- Metric fixture exposed a data.table name collision between slope fit and slope column; coefficient is now extracted outside table scope.
- Official B/C each have one conflicting time-zero Weight descriptor. CP3 adapter uses first source record for admission extraction while restoring every original window measurement and summary. Synthetic tests check count/mean and unsorted-ID alignment. The unchanged CP2 constructor is used when no conflict occurs.
- Official C contains 2,403 observations without variable names across 1,594 stays. The CP3 reader preserves raw files, audits source lines and omits these unassignable records without guessing labels. All stays remain. This source-information loss is documented as a limitation.
- Exact task initially failed because CP3 was absent from Quarto's explicit project render list. Only the required single list entry was added; project mode preserves existing reports.
- Independent review caught singleton subgroup calibration (`var` undefined for n=1) and wrong PR stair direction under ties. New singleton RED/GREEN fixture and prevalence guard fix the first; vertical-first PR rendering matches the AP convention for the second.
- Case inspection found WBC=12,500 contributing about +35 log-odds for the highest-risk survivor, saturating risk. The report flags possible unit/scale/entry concern without guessing a correction or changing predictions. An explicit case-review fixture checks this diagnostic flag.
- A fixture's exact floating-point equality to 0.64 was corrected to a tight numerical tolerance; this was a test precision mistake, not a changed Brier formula.

## Tests and review

Three final CP3 R fixture files pass. Eleven selected regression/audit commands pass, including the original loader (which exercises CP1 rounds), CP2 result/artifact/reload/partition checks, original CP2 report and render-safety tests, plus frozen audit. No claim is made that every historical smoke/timing script was rerun. Final report checks and fresh-report checks pass; six numeric outputs match exactly. No R analysis warnings occurred; Pixi reports an existing detached-environment notice, and Quarto may emit its standard rendering notices. No environment deletion or lock re-resolution was performed.

A fresh independent senior reviewer inspected all CP3 code/tests, manifests, configuration, report, outputs and all six figures. Two Important findings above were fixed; no unresolved Critical/Important finding remained. The minor calibration-interpretation suggestion was incorporated. Final refreshed artifact/portability confirmation is recorded in the local execution ledger and closeout evidence.

## Checklist mapping

| Professor requirement | Evidence |
|---|---|
| Same features, saved model/preprocessing, no B/C tuning | CP3 data adapter; frozen artifact checks; section 3.1 |
| Counts/deaths; B/C and benchmark AUROC/CIs; CV comparison and chance | Tables 1–4, section 3.2 |
| B precision–recall and prevalence | Figure 1, section 3.2 |
| Flexible calibration/bands/risk support, intercept/slope, Brier | Figures 2–3, Tables 5–6, section 3.3 |
| Model/SOFA/all/none DCA, fixed clinical use and threshold, event1 | Figures 4–5, Tables 7–9, section 3.4 |
| Age/sex/ICU subgroup AUROC and calibration with n/deaths | Table 10, section 3.5 |
| Regression coefficients and noncausal example | Figure 6, Table 11, section 3.6 |
| Five high-risk survivors/five low-risk deaths with drivers/judgments | Tables 12–14, section 3.7 |
| Usefulness, limits, leakage, causality, AI disclosure | Section 3.8 and opening statement |
| One-command report, runtime, packages, reproducibility | Named task, README, Table 16, original and fresh execution |

## Evidence locations

- `output/cp3_verification.json`: machine-readable closeout.
- `output/cp3_final_main_execution.json` and log; `output/cp3_fresh_execution.json` and fresh log path.
- `output/cp3_final_fixtures.json`, `output/cp3_regression_results.json`.
- `output/cp3_portability.json`, `output/cp3_fresh_snapshot.json`.
- `output/cp3_input_preservation.json`, `output/cp3_preprocessing_digest.txt`.
- `output/cp3_execution_ledger.txt`: rulings, test failures and corrections.
- `data/official-cp3-download-manifest.json`: official source URLs and fingerprints.

Future publication requires separate user authorization. The local and previously API-published CP2 histories differ despite their identical trees; do not attempt a normal push or rewrite to hide that difference.

Final independent recheck: **ready for user review, no remaining material findings**. The reviewer independently compared the fresh outputs and hashes, re-ran report/preservation checks, and checked the new case flag. Full final verdict: `output/cp3_independent_review.txt`. Coordinator additionally inspected the final HTML in the browser; wide tables support horizontal scrolling at a narrow 706px viewport. Screenshot: `output/cp3_browser_check.png`. The report-only loopback server was stopped.

## Submission-readiness editorial pass, 2026-11-05

User confirmed manual review complete. AI disclosure reduced to 66 words while retaining truthful scope, checks, benefits and limitations. Exact grader command passed in 123.61s; report/protected-file checks passed and all six core CSVs and original model/report hashes remain unchanged. Details: `output/cp3_submission_readiness_2026-11-05.txt`. Files remain uncommitted/unpublished; current GitHub tree has no CP3 content. Prior fresh-snapshot evidence covers the unchanged computational implementation.

User-requested disclosure revision: expanded from 66 to 204 words to emphasize advantages and disadvantages, rather than a detailed workflow. One brief scope sentence is retained. The user-confirmed human review is acknowledged. Only the AI-use sections in source and rendered HTML changed; byte comparisons confirm everything outside those sections is identical. Analyses were not rerun for this prose-only change. Evidence: `output/cp3_disclosure_reflection_revision.json`. This supersedes the shorter disclosure wording, not any numerical validation.
