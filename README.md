# Analysis code and study-level data for: Perioperative Biologic Therapy in Psoriasis and Psoriatic Arthritis: A Systematic Review and Meta-analysis of Evidence Relevant to Orthopaedic Surgery

Version 1.0.0. Author: Samer G. Salman, M.D. Candidate, Baylor College of Medicine, Houston, TX, USA.

Archived DOI: not yet assigned. After release, the archived DOI will be listed here, at the top of this README, and in `CITATION.cff`.

## What this is

This repository holds the analysis code and the study-level data for a systematic review and meta-analysis of perioperative biologic therapy in patients with psoriasis or psoriatic arthritis who undergo surgery that includes orthopaedic procedures. The analyses compare continued with held biologic therapy around surgery for postoperative infection and wound-healing complications and for skin or joint flare. It is a research record, not clinical guidance.

It contains the R script that fits the random-effects and sensitivity meta-analyses and writes the summary-of-findings table and the forest plots, the Python scripts that draw the PRISMA flow diagram and the risk-of-bias figures, and a single-command driver (`run_all.sh`) that regenerates the results file, the summary-of-findings table, the sensitivity-analysis output and the figures and compares the regenerated numerical results with the deposited reference file. It also contains the extracted study-level data, the risk-of-bias assessments and the generated results.

The deposited data are study-level data extracted from published reports and aggregate counts; see the data dictionary below. `data/extraction_master.csv` also contains descriptive fields (age, sex, procedure and outcome) for three published case reports or small case series, Kawakami 2016, Koga 2025 and Kunimi 2018, as printed in those reports.

The files and the denominator that each count refers to:

| File | Rows | Columns | One row is |
|---|---|---|---|
| `data/extraction_master.csv` | 23 | 38 | one arm and outcome of one study (up to 4 rows per study; 12 studies) |
| `data/poolable_dataset.csv` | 24 | 10 | one arm and outcome entered in a meta-analysis (7 studies) |
| `data/study_map.csv` | 12 | 7 | one included study |
| `rob/robins_i_assessments.csv` | 8 | 18 | one study assessed with ROBINS-I |
| `rob/jbi_assessments.csv` | 4 | 17 | one study assessed with the JBI checklists |

Of the 12 included studies, 7 enter at least one meta-analysis and 5 are described narratively only. The ROBINS-I and JBI files together cover the same 12 studies. `data/prisma_counts.json` holds the 26 counts that `analysis/prisma_figure.py` draws.

## How to cite

Please credit the author and cite the archived release. The machine-readable form is in `CITATION.cff`. In plain text:

> Salman SG. Analysis code and study-level data for: Perioperative Biologic Therapy in Psoriasis and Psoriatic Arthritis: A Systematic Review and Meta-analysis of Evidence Relevant to Orthopaedic Surgery. Version 1.0.0. Available from: https://github.com/samersalman/psoriasis-ortho-biologic-meta-analysis

No DOI is listed yet. After release, the archived DOI will be listed at the top of this README and in `CITATION.cff`, and the citation above should then be used with that DOI.

## Repository layout

```
.
|-- analysis/
|   |-- compare_results.py                  compares two results.json files
|   |-- meta_analysis.R                     meta-analyses; writes results, Table 3, Figures 3 to 5
|   |-- prisma_figure.py                    draws Figure1_PRISMA (PRISMA flow diagram)
|   `-- rob_figure.py                       draws Figure2_RoB (ROBINS-I summary)
|-- data/
|   |-- extraction_master.csv               extracted study-level data
|   |-- poolable_dataset.csv                event counts and denominators entered in the pools
|   |-- prisma_counts.json                  counts drawn in Figure1_PRISMA
|   `-- study_map.csv                       role of each included study
|-- environment/
|   `-- R-sessionInfo.txt                   recorded R session
|-- outputs/
|   |-- figures/                            Figures 1 to 5, each as PNG and PDF
|   |   |-- Figure1_PRISMA.pdf and .png
|   |   |-- Figure2_RoB.pdf and .png
|   |   |-- Figure3_forest_SSI.pdf and .png
|   |   |-- Figure4_forest_flare.pdf and .png
|   |   `-- Figure5_forest_proportions.pdf and .png
|   |-- static_tables/                      hand-curated or derived once; never written by run_all.sh
|   |   |-- table1_consolidated.csv and .json
|   |   |-- table2_grade.csv and .json
|   |   |-- tableS1_characteristics.csv and .json
|   |   |-- tableS2_evidence_matrix.csv and .json
|   |   |-- tableS3_outcomes.csv and .json
|   |   `-- tableS4_sensitivity.csv and .json
|   |-- supplement/
|   |   `-- sensitivity_output.md           sensitivity and robustness output
|   |-- tables/
|   |   `-- Table3_GRADE_SoF.csv            summary-of-findings table
|   `-- results.json                        all numerical results (reference file)
|-- rob/
|   |-- jbi_assessments.csv                 JBI checklist responses
|   `-- robins_i_assessments.csv            ROBINS-I judgements
|-- CHANGES_FROM_PROJECT.md                 changes made to the project files for this deposit
|-- CITATION.cff                            citation metadata
|-- LICENSE                                 MIT licence text (code)
|-- LICENSE-DATA                            CC BY 4.0 licence text (everything that is not code)
|-- MANIFEST.sha256                         checksums of the deposited files
|-- README.md                               this file
|-- requirements.txt                        Python package versions
|-- run_all.sh                              single-command driver
|-- .gitattributes                          byte-preserving checkout
|-- .gitignore                              ignored files
`-- .zenodo.json                            archive deposition metadata
```

`CHANGES_FROM_PROJECT.md` lists every change made to the author's project files when they were copied here, and the known inaccuracies in the copied scripts that were left unchanged. The three scripts in `analysis/` differ from the project's scripts only in 12 whole lines: 11 that set input and output paths and one that sets the heading of a notes section in the sensitivity output.

## Data dictionary

Study values (population, counts, percentages, ranges and effect estimates) are as printed in the source articles; columns that classify or comment on a row (for example `analysis`, `contrast_type`, `PsA_isolable`, `mixed_cohort_caveat`, `overlap_companion_flag` and `notes`) hold the classifications and notes recorded during data extraction; a blank field means no value was recorded for that row. Every CSV file has a header row. Eight CSV files use CRLF line endings, as in the project: `data/extraction_master.csv`, `data/poolable_dataset.csv` and the six CSV files in `outputs/static_tables/`; `.gitattributes` keeps them unchanged.

### `data/poolable_dataset.csv`

The only data file read by `analysis/meta_analysis.R`, which uses `study_id`, `study_label`, `analysis`, `arm`, `events` and `n`. The other columns document the row.

| Column | Content |
|---|---|
| `study_id` | Identifier that links a study across all files in `data/` and `rob/`. |
| `study_label` | First author and publication year. |
| `analysis` | The pool the row belongs to: `MA1_SSI` (8 rows; continued versus held therapy, infection or wound complication), `MA2_flare` (4; continued versus held, disease flare), `MA3_SSIprop` (5; single-arm proportion with infection or wound complication among patients who continued), `MA3_PJIprop` (3; single-arm proportion with peri-prosthetic joint infection), `MA4_flareprop` (4; flare proportions by arm). |
| `arm` | `continue`, `discontinue` or `single` (a single-arm cohort). |
| `outcome` | `SSI_wound` (surgical-site infection or wound complication, as each study defined it), `flare` or `PJI` (peri-prosthetic joint infection). |
| `events`, `n` | Number of patients or procedures with the outcome, and the denominator, as entered in the pool. The unit differs between studies; `outputs/tables/Table3_GRADE_SoF.csv` says which unit each pool combines. |
| `contrast_type` | How the contrast between arms was defined: `design-level` or `user-vs-nonuser`. |
| `page_cite` | Page or table locator in the source article for the values entered. Every row has one. |
| `notes` | Free-text note on how the values were taken (denominator choice, overlap rule). |

Odds ratios compare the continued arm with the held (discontinued) arm: a value above 1 means more events with continuation (`outputs/results.json`, `meta.or_convention`).

### `data/extraction_master.csv`

Not read by any script. Values are as reported in the source articles and kept as text (counts, percentages, means and ranges as printed). Columns in file order, grouped:

| Columns | Content |
|---|---|
| `study_id`, `study_label`, `country`, `journal`, `year`, `design` | Identification and study design. |
| `role_in_synthesis` | The pools the study enters, or narrative only. |
| `total_N`, `psoriasis_n`, `PsA_n`, `other_dx`, `age`, `sex`, `diabetes_comorbidity` | Study population. |
| `surgery_types`, `ortho_n_over_total`, `elective_vs_urgent` | Procedures, how many were orthopaedic, and whether elective. |
| `agents`, `contrast_type`, `n_continue`, `n_discontinue`, `hold_restart_timing` | Biologic drug names, how the exposure contrast was defined, group sizes, and timing of holding and restarting. |
| `outcome`, `arm`, `events`, `n`, `definition`, `follow_up` | One outcome in one arm, its count and denominator, its definition and the follow-up. |
| `effect_measure`, `effect_estimate`, `effect_ci`, `effect_p`, `adjusted_vs_crude`, `covariates` | Effect estimate as published, whether adjusted, and the covariates. |
| `PsA_isolable`, `mixed_cohort_caveat`, `overlap_companion_flag`, `notes` | Whether psoriatic arthritis results can be isolated, cohort-mix caveat, overlap with another included study (an overlap rule keeps overlapping studies out of the same pool), free-text notes. |

### `data/study_map.csv`

Not read by any script. `study_id`, `label`, `author_year`, `design` (short category), `role_in_synthesis` (short description), `contrast_type` (short category) and `pools` (the pools the study enters, separated by semicolons, or `narrative`).

### `rob/robins_i_assessments.csv` and `rob/jbi_assessments.csv`

Both are read by `analysis/rob_figure.py`.

| Column | Content |
|---|---|
| `study_id`, `study_label` | As above. |
| `D1` to `D7`, `Overall` (ROBINS-I) | Judgement (the values in the file are `Low`, `Moderate` and `Serious`) for confounding, selection of participants, classification of interventions, deviations from intended interventions, missing data, measurement of outcomes, selection of the reported result, and overall. |
| `D1_rationale` to `D7_rationale`, `Overall_rationale` (ROBINS-I) | Short written reason for each judgement. |
| `checklist_type` (JBI) | `case_series` or `case_report`; the item wording for each is in `analysis/rob_figure.py`. |
| `Q1` to `Q10` (JBI) | Response to each checklist item: `Yes`, `Unclear` or `NA` (not applicable); the figure script also accepts `No`. |
| `n_yes`, `n_total` (JBI) | Number of `Yes` responses, and number of items in the checklist for that type. |
| `overall_appraisal`, `rationale` (JBI) | Overall appraisal and written reason. |

### `data/prisma_counts.json`

The 26 counts in 4 blocks that `analysis/prisma_figure.py` reads: records identified (by database and in total), duplicates removed, and the counts at each later stage of the flow diagram down to the studies included.

### Generated files in `outputs/`

| File | Content |
|---|---|
| `outputs/results.json` | Every numerical result, in four sections: `meta` (R and package versions, run date `date_run`, estimator, odds-ratio convention, overlap-rule check, and an `input` label that names `poolable_dataset.csv` as sitting in the project's `extraction` folder; the file is `data/poolable_dataset.csv` here, see `CHANGES_FROM_PROJECT.md`), `analyses` (one object per pool, with primary, per-study and sensitivity results), `narrative` (studies that are not pooled) and `grade` (certainty-of-evidence rows). |
| `outputs/tables/Table3_GRADE_SoF.csv` | Summary-of-findings table. The pooled estimates are computed by the script; the certainty ratings and footnotes are judgements entered in the script. It is the unedited R output, so its column names keep R-style underscores. |
| `outputs/supplement/sensitivity_output.md` | Sensitivity and robustness results written by `analysis/meta_analysis.R`. |
| `outputs/figures/` | Figure1_PRISMA (flow diagram), Figure2_RoB (ROBINS-I summary), Figure3_forest_SSI and Figure4_forest_flare (forest plots of the two comparative pools) and Figure5_forest_proportions (pooled single-arm proportions). |
| `outputs/static_tables/` | Twelve files: six tables (`table1_consolidated`, `table2_grade`, `tableS1_characteristics`, `tableS2_evidence_matrix`, `tableS3_outcomes`, `tableS4_sensitivity`), each as a CSV file and as a JSON file. The JSON file adds the table title, caption, abbreviations and footnotes. These tables are hand-curated, except `tableS4_sensitivity` and the pooled-effect and certainty columns of `table2_grade`, which were derived once from `outputs/results.json`. |

The numbers in the output file names (Figure1_PRISMA to Figure5_forest_proportions, Table3_GRADE_SoF.csv) were assigned while the analysis was developed. In this README, Figure 1 to Figure 5 and Table 3 refer to those file names and may differ from the numbering of any article that uses these outputs.

## Software requirements

| Component | Version used |
|---|---|
| R | 4.6.0 (2026-04-24) |
| metafor | 5.0-1 (shown as 5.0.1 by `packageVersion`) |
| lme4 | 2.0-1 (shown as 2.0.1) |
| jsonlite | 2.0.0 |
| Python | 3.14.0 |
| matplotlib | 3.10.8 (the other Python packages are listed in `requirements.txt`) |

`analysis/compare_results.py` uses the Python standard library only. `run_all.sh` needs bash. `environment/R-sessionInfo.txt` records the full R session. `outputs/results.json` records R, metafor and jsonlite versions in `meta`, but not lme4. Only macOS on Apple silicon (arm64) was tested.

lme4 is required by the generalized linear mixed-effects sensitivity analysis (`rma.glmm` in metafor). `run_all.sh` checks for it first and stops with a message if it is missing. A comment at the top of `analysis/meta_analysis.R` says that no package beyond metafor and jsonlite is needed; that comment is out of date. If `analysis/meta_analysis.R` is run alone without lme4, it still finishes and prints a line that starts `GLMM failed:`, but `outputs/results.json` then has 343 numeric values instead of 347, and the comparison fails.

## How to reproduce

1. Install the dependencies: R with the three packages above from CRAN, and Python 3 with `python3 -m pip install -r requirements.txt`.
2. From the repository root, check the download, then run everything:

```
shasum -a 256 -c MANIFEST.sha256
bash run_all.sh
```

Run the checksum command before the first run: a run changes some files (see below), and the checksum list will then report them as FAILED. `MANIFEST.sha256` lists the SHA-256 checksum of every deposited file. `run_all.sh` can be started from any directory and from a folder name that contains spaces; set the `PYTHON` environment variable to choose the Python interpreter. It takes a few seconds. Its steps are:

1. check that Rscript, Python, metafor, jsonlite, lme4 and matplotlib are available;
2. copy the deposited `outputs/results.json` to a temporary folder, because the R script overwrites it in place;
3. run `analysis/meta_analysis.R`;
4. run `analysis/compare_results.py`, which compares the new `outputs/results.json` with the deposited copy value by value (only `meta.date_run` is ignored) and stops the run with exit status 1 if any value differs;
5. run `analysis/prisma_figure.py`;
6. run `analysis/rob_figure.py`.

### What a run regenerates, and what it does not

`bash run_all.sh` regenerates the meta-analysis results, Figures 1 to 5 and Table 3 in `outputs/`. It never writes `outputs/static_tables/`.

| Output | Written by `run_all.sh` | On the tested stack |
|---|---|---|
| `outputs/results.json` | yes | Same values as the deposit except `meta.date_run`: the comparison reports 347 numeric, 194 string and 1 boolean values compared and 0 differences. |
| `outputs/tables/Table3_GRADE_SoF.csv` | yes | Byte-identical. |
| `outputs/figures/` PNG files (five) | yes | Byte-identical. |
| `outputs/figures/` PDF files (five) | yes | Differ only in the PDF creation timestamp. |
| `outputs/supplement/sensitivity_output.md` | yes | Identical except the "Generated" date on line 3. |
| `outputs/static_tables/` (twelve files) | no | Hand-curated or derived once; never written, never compared. |

Byte identity of the PNG files was observed on the machine and software stack of the deposit; another stack can change the last digit of a rounded value or the bytes of a PNG, and the comparison reports any numerical difference. If the matplotlib or font build changes text sizes, `analysis/prisma_figure.py` stops with a layout error. To compare on another machine, skip the software-version strings:

```
COMPARE_ARGS="--ignore meta.R_version --ignore meta.packages.metafor --ignore meta.packages.jsonlite" bash run_all.sh
```

**Comparison with the deposit happens only on the first run in a fresh checkout.** `run_all.sh` overwrites `outputs/results.json` in place, so a second run in the same folder compares with the first run's output. To compare with the deposit again, restore the deposited files with `git checkout -- outputs`, or clone again. After a run, `git status` shows `outputs/results.json`, `outputs/supplement/sensitivity_output.md` and the five PDF figures as modified when the run day differs from the date in the deposited `meta.date_run`.

Running `analysis/rob_figure.py` also writes a supplementary risk-of-bias figure for the JBI assessments, `outputs/supplement/FigureS1_JBI.png` and `outputs/supplement/FigureS1_JBI.pdf`. These two files are not part of the deposit and are listed in `.gitignore`. Do not save run logs inside the repository: the R script prints absolute paths of the machine it runs on.

### Determinism

The analyses are deterministic. The script calls `set.seed(42)`, but no step draws random numbers: re-running the R script with a different seed, or with the seed call removed, reproduced every value in `outputs/results.json` other than the run date. No reported value depends on the seed. This was tested on the stack above only.

## What the R script computes

`analysis/meta_analysis.R` fits random-effects (REML) meta-analyses with metafor for the five pools (odds ratios for the two comparative pools, logit-transformed proportions for the other three) and reports prediction intervals. Its sensitivity analyses are fixed-effect, Mantel-Haenszel, Peto, generalized linear mixed-effects, leave-one-out and subgroup analyses, and the Freeman-Tukey double-arcsine transformation for the proportions. It stops with an error if the two cohorts flagged as overlapping (column `overlap_companion_flag` of `data/extraction_master.csv`; the script holds their two study identifiers itself) ever appear in the same pool. It writes `outputs/results.json`, `outputs/tables/Table3_GRADE_SoF.csv`, `outputs/supplement/sensitivity_output.md` and Figures 3 to 5.

## Licensing

Every file in this repository whose name ends in .py, .R or .sh is licensed under the MIT License; every other file in this repository is licensed under the Creative Commons Attribution 4.0 International licence (CC BY 4.0).

| Files | Licence | Text |
|---|---|---|
| `analysis/meta_analysis.R`, `analysis/prisma_figure.py`, `analysis/rob_figure.py`, `analysis/compare_results.py`, `run_all.sh` | MIT | `LICENSE` |
| Everything else: the data, the generated outputs, `environment/`, and the documentation and configuration files | CC BY 4.0 | `LICENSE-DATA` |

The repository carries both licence texts, as `LICENSE` (MIT) and `LICENSE-DATA` (CC BY 4.0). `outputs/static_tables/` is data and is licensed under CC BY 4.0. The source articles remain the copyright of their publishers; they are identified by study label, year and journal, and no article file is redistributed.

## Not included

- raw database exports;
- publisher PDFs, full texts, abstracts and verbatim excerpts of the source articles (values entered in a meta-analysis carry a page or table locator in the `page_cite` column of `data/poolable_dataset.csv`);
- code that assembles the manuscript and supplementary documents, which performs no statistical computation;
- a superseded extraction-table builder;
- earlier working notes and drafts.

## Contact and attribution

Samer G. Salman, M.D. Candidate, Baylor College of Medicine, Houston, TX, USA. For questions about the code or the data, open an issue in this GitHub repository. Please credit the author as described in `LICENSE-DATA`.
