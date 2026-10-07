# Changes from the project files

This file lists every change made to the author's project files when they were copied into this repository, and the known inaccuracies in the copied files that were left unchanged. "The project" is the author's original working folder; "the repository" is this deposit. Passages that were removed from cells are not reproduced here.

## 1. Summary by category

| Category | Files | Count |
|---|---|---|
| Copied unchanged (byte-identical to the project file) | `outputs/results.json`; `rob/robins_i_assessments.csv` and `rob/jbi_assessments.csv`; the ten files in `outputs/figures/`; `outputs/tables/Table3_GRADE_SoF.csv`; the twelve files in `outputs/static_tables/` | 26 |
| Copied with whole-line edits (section 2) | `analysis/meta_analysis.R`, `analysis/prisma_figure.py`, `analysis/rob_figure.py` | 3 |
| Regenerated with the edited `analysis/meta_analysis.R` (section 2) | `outputs/supplement/sensitivity_output.md` | 1 |
| Copied with cell or column edits (section 3) | `data/poolable_dataset.csv`, `data/extraction_master.csv`, `data/study_map.csv` | 3 |
| Derived from a project file (section 4) | `data/prisma_counts.json` | 1 |
| Written for this deposit | `analysis/compare_results.py`, `run_all.sh`, `requirements.txt`, `environment/R-sessionInfo.txt`, `LICENSE`, `LICENSE-DATA`, `CITATION.cff`, `.zenodo.json`, `.gitattributes`, `.gitignore`, `README.md`, `CHANGES_FROM_PROJECT.md`, `MANIFEST.sha256` | 13 |

The six categories add up to 47 files, the whole repository once `README.md`, `CHANGES_FROM_PROJECT.md` and `MANIFEST.sha256` are in place.

## 2. Whole-line edits in the scripts

Twelve whole lines were replaced: seven in `analysis/meta_analysis.R`, two in `analysis/prisma_figure.py` and three in `analysis/rob_figure.py`. Eleven of them replace paths that belonged to the project folder layout with paths relative to the repository. The twelfth, line 720 of `analysis/meta_analysis.R`, replaces the working heading of the notes section that the script writes into `outputs/supplement/sensitivity_output.md` with a plain heading. No line was added or removed (the three scripts have 810, 424 and 496 lines) and no other line differs from the project files. Line numbers are the same in the project and in the repository.

`outputs/supplement/sensitivity_output.md` was regenerated with the edited script on 2026-10-07 and differs from the project's file in two lines only: the heading on line 5 and the "Generated" date on line 3. `outputs/results.json` is the project's file from the earlier run (`meta.date_run` 2026-07-24); a fresh run of the edited script reproduces its 347 numeric, 194 string and 1 boolean values with 0 differences.

Four of the old expressions cannot be shown as written: two contain the absolute path of the author's computer, one names a working folder of the project and one is the working heading of the notes section. They are described in angle brackets.

```
analysis/meta_analysis.R
L21 old: PROJ <- <the absolute path of the author's project folder>
L21 new: PROJ <- local({ a <- grep("^--file=", commandArgs(FALSE), value = TRUE); if (length(a)) normalizePath(file.path(dirname(gsub("~+~", " ", sub("^--file=", "", a[1]), fixed = TRUE)), "..")) else normalizePath(".") })
L22 old: DAT  <- file.path(PROJ, "extraction", "poolable_dataset.csv")
L22 new: DAT  <- file.path(PROJ, "data", "poolable_dataset.csv")
L23 old: FIGDIR <- file.path(PROJ, "manuscript", "v1", "figures")
L23 new: FIGDIR <- file.path(PROJ, "outputs", "figures")
L24 old: TABDIR <- file.path(PROJ, "manuscript", "v1", "tables")
L24 new: TABDIR <- file.path(PROJ, "outputs", "tables")
L25 old: SUPDIR <- file.path(PROJ, "manuscript", "v1", "supplement")
L25 new: SUPDIR <- file.path(PROJ, "outputs", "supplement")
L532 old: json_path <- file.path(PROJ, "analysis", "results.json")
L532 new: json_path <- file.path(PROJ, "outputs", "results.json")
L720 old: add("## <the working heading of the notes section>")
L720 new: add("## NOTES ON INTERPRETATION")

analysis/prisma_figure.py
L43 old: COUNTS_JSON = os.path.join(ROOT, <a working folder of the project>, "prisma_counts.json")
L43 new: COUNTS_JSON = os.path.join(ROOT, "data", "prisma_counts.json")
L44 old: OUT_DIR = os.path.join(ROOT, "manuscript", "v1", "figures")
L44 new: OUT_DIR = os.path.join(ROOT, "outputs", "figures")

analysis/rob_figure.py
L52 old: ROOT = <the absolute path of the author's project folder>
L52 new: ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
L54 old: FIG_DIR = os.path.join(ROOT, "manuscript", "v1", "figures")
L54 new: FIG_DIR = os.path.join(ROOT, "outputs", "figures")
L55 old: SUP_DIR = os.path.join(ROOT, "manuscript", "v1", "supplement")
L55 new: SUP_DIR = os.path.join(ROOT, "outputs", "supplement")
```

The new line 21 of `analysis/meta_analysis.R` finds the repository root from the script's own location. It works from any working directory and from a folder name that contains spaces; run the script with `Rscript`, not with `R -f`. The new line 52 of `analysis/rob_figure.py` does the same through `__file__`. The input files and output folders are otherwise untouched.

## 3. Cell-level changes to the data files

Line numbers are file lines, with the header as line 1. Row counts, line endings and quoting are unchanged, column counts are unchanged except in `data/study_map.csv`, and every cell not listed below is byte-identical to the project file. The columns that `analysis/meta_analysis.R` reads from `data/poolable_dataset.csv` are byte-identical to the project file, and a run of the repository code on the edited files reproduced `outputs/results.json` with 0 differences (`analysis/compare_results.py`). No script reads `data/extraction_master.csv` or `data/study_map.csv`.

### `data/poolable_dataset.csv` (5 cells)

| Line | Row | Column | Change |
|---|---|---|---|
| 8 | `EMBASE3-0011`, Fabiano 2014, `MA1_SSI`, `continue` | `notes` | Removed the quotation marks around a short phrase and changed the verb that introduced it; the words of the phrase are unchanged. |
| 9 | `EMBASE3-0011`, Fabiano 2014, `MA1_SSI`, `discontinue` | `page_cite` | Removed quoted fragments of the source text; the page and table locator is kept. |
| 19 | `EMBASE2-0040`, Borgas 2020, `MA3_PJIprop`, `single` | `page_cite` | Removed quoted fragments of the source text; the locator is kept. |
| 20 | `EMBASE2-0082`, George 2017, `MA3_PJIprop`, `continue` | `notes` | Deleted the final sentence, a cross-reference. The rest of the cell is unchanged. |
| 21 | `EMBASE2-0014`, Nguyen 2021, `MA3_PJIprop`, `single` | `page_cite` | Removed quoted fragments of the source text; the locator is kept. |

### `data/extraction_master.csv` (14 cells)

| Line | Row | Column | Change |
|---|---|---|---|
| 3 | `EMBASE3-0017`, Berthold 2013, `SSI_wound`, discontinue (Group A) | `events` | Rewrote the note on where the value and the alternative count in the Results text come from: table names written out, the page of the Results text given, and a figure reference removed, to agree with `data/poolable_dataset.csv`. |
| 4, 5, 6, 7 | `EMBASE2-0014`, four rows | `study_label` | Corrected the year in the label to the value in the `year` column of the same rows (2021); the label now agrees with `data/poolable_dataset.csv`. |
| 8, 9, 10, 11 | `EMBASE2-0094`, four rows | `study_label` | Corrected the year in the label to the value in the `year` column of the same rows (2016); the label now agrees with `data/poolable_dataset.csv`. |
| 7 | `EMBASE2-0014`, Nguyen 2021, `flare`, discontinue | `notes` | Deleted a parenthetical cross-reference. |
| 20, 21 | `PUBMED-0031`, Day 2023, two rows | `hold_restart_timing` | Replaced a quotation from the source with a statement, without quotation marks, that the timing of discontinuation around surgery could not be determined. |
| 22 | `EMBASE2-0091`, Kawakami 2016 | `notes` | Reworded the note as a plain statement of the course of the orthopaedic case and of the other three cases, which are non-orthopaedic. The clinical content is unchanged. |
| 24 | `PUBMED-0173`, Kunimi 2018 | `contrast_type` | Replaced a short quotation with a paraphrase. |

### `data/study_map.csv`

Two columns were dropped, `pdf_filename` and `fulltext_file`. They named publisher PDFs and text extracts that are not part of the deposit. The remaining 7 columns and 12 rows are unchanged.

## 4. Derived file

`data/prisma_counts.json` is a counts-only subset of the project's flow-count file: 26 values in 4 blocks. Every value equals the project's value. It keeps only the entries that `analysis/prisma_figure.py` reads, and the script's own arithmetic checks on the counts pass.

## 5. Known inaccuracies left unchanged

The following are comments in the original scripts that were left unchanged, so that apart from the 12 lines of section 2 every script line is as it was in the project.

- **`meta.input` label.** `analysis/meta_analysis.R` line 137 writes a provenance label into `outputs/results.json` (`meta.input`). The label names the input file by its location in the project layout, not by its location here:

  ```
  input = "extraction/poolable_dataset.csv"
  ```

  The file is `data/poolable_dataset.csv`. The label was kept because changing it would make every fresh `outputs/results.json` differ from the deposited reference file, and the comparison in `run_all.sh` would fail. A comment at line 543 of the same script names the file the same way.
- **Header comments of `analysis/meta_analysis.R` (lines 1 to 12).** They say that the script produces Figures 3 and 4; it writes Figures 3 to 5. They say that no package beyond metafor and jsonlite is needed; lme4 is also required (see `README.md`). They name output folders of the project layout, and they give a working title of the review that differs from the article title. The heading comment at line 538 refers to a companion helper that assembles a document; that code is not part of this repository.
- **Docstring and a comment of `analysis/prisma_figure.py` (the docstring at the top of the file, and line 319).** They give the same working title, name the project's counts file and a diagram-structure file, and name project output folders. The script reads `data/prisma_counts.json` only and does not read a diagram-structure file.
- **Docstring of `analysis/rob_figure.py` (at the top of the file).** It gives the same working title, names project output folders, and refers to earlier drafts of the article by version number. It calls the supplementary JBI figure "the BioRender version"; the deposit does not contain that figure.

## 6. Files whose bytes change on every run

These change whenever `run_all.sh` is run on a different day from the deposit, although every numerical value is the same:

- `outputs/results.json`: `meta.date_run` (line 14);
- `outputs/supplement/sensitivity_output.md`: the "Generated" date on line 3;
- the five PDF files in `outputs/figures/`: the PDF creation timestamp.

`MANIFEST.sha256` records the files as deposited, so check the download with `shasum -a 256 -c MANIFEST.sha256` before the first run. See `README.md`, section "How to reproduce".
