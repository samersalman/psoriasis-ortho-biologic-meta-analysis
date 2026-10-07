#!/usr/bin/env bash
# Regenerate the statistical results and figures in this repository, and check the
# regenerated numbers against the deposited reference file.
#
#   1. Pre-flight checks for Rscript, python3, the R packages metafor, jsonlite and
#      lme4, and the Python package matplotlib.
#   2. Copy the deposited outputs/results.json to a temporary folder. The R script
#      overwrites that file in place, so the reference has to be set aside first.
#   3. analysis/meta_analysis.R fits every meta-analysis and writes outputs/results.json,
#      outputs/tables/Table3_GRADE_SoF.csv, outputs/figures/Figure3 to Figure5 and
#      outputs/supplement/sensitivity_output.md.
#   4. analysis/compare_results.py compares the new outputs/results.json with the
#      deposited copy, leaf by leaf, ignoring only meta.date_run. A difference stops
#      the script with exit status 1.
#   5. analysis/prisma_figure.py draws outputs/figures/Figure1_PRISMA from
#      data/prisma_counts.json.
#   6. analysis/rob_figure.py draws the risk-of-bias figures from rob/*.csv.
#
# outputs/static_tables/ is hand-curated or derived once from results.json; this
# script never writes it.
#
# After a run, outputs/results.json carries the new meta.date_run and the "Generated"
# date in outputs/supplement/sensitivity_output.md changes, so both show as modified
# when the run day differs from the deposit.
#
# The reference is whatever outputs/results.json holds when the script starts. A first
# run replaces it, so a second run in the same folder compares against the first run's
# output. To check against the deposited file again, restore it first (for example
# "git restore outputs/results.json" in a clone) or use a fresh clone.
#
# Environment variables (both optional):
#   PYTHON        Python interpreter to use (default: python3). It must have matplotlib.
#   COMPARE_ARGS  extra options for compare_results.py, for example, on another machine,
#                 "--ignore meta.R_version --ignore meta.packages.metafor
#                  --ignore meta.packages.jsonlite" to skip the software-version strings.
#
# Usage:  bash run_all.sh

set -euo pipefail
cd "$(dirname "$0")"

PYTHON="${PYTHON:-python3}"

echo "=== 1/6  pre-flight checks ==="
if ! command -v Rscript >/dev/null 2>&1; then
  echo "ERROR: Rscript was not found on PATH. Install R (4.6.0 was used; see environment/R-sessionInfo.txt)." >&2
  exit 1
fi
if ! command -v "$PYTHON" >/dev/null 2>&1; then
  echo "ERROR: the Python interpreter '$PYTHON' was not found. Install Python 3 or set PYTHON=/path/to/python3." >&2
  exit 1
fi
for pkg in metafor jsonlite lme4; do
  if ! Rscript -e "if (!requireNamespace('$pkg', quietly = TRUE)) quit(status = 1)" >/dev/null 2>&1; then
    echo "ERROR: the R package '$pkg' is not installed." >&2
    if [ "$pkg" = "lme4" ]; then
      echo "       lme4 is required by the generalized linear mixed model sensitivity analysis (rma.glmm)." >&2
      echo "       Without it meta_analysis.R still finishes, but results.json silently loses those numbers" >&2
      echo "       and the comparison with the deposited file fails." >&2
    fi
    echo "       Install it in R with: install.packages('$pkg')  (versions used: see environment/R-sessionInfo.txt)" >&2
    exit 1
  fi
done
if ! "$PYTHON" -c "import matplotlib" >/dev/null 2>&1; then
  echo "ERROR: the Python package matplotlib is not importable with '$PYTHON'." >&2
  echo "       Install it with: $PYTHON -m pip install -r requirements.txt   (or set PYTHON to an interpreter that has it)" >&2
  exit 1
fi
echo "Rscript, $PYTHON, metafor, jsonlite, lme4 and matplotlib are available."

echo
echo "=== 2/6  set aside the deposited results.json ==="
ref_dir="$(mktemp -d)"
trap 'rm -rf "$ref_dir"' EXIT
ref="$ref_dir/results.deposited.json"
cp outputs/results.json "$ref"
echo "Reference copy made."

echo
echo "=== 3/6  meta_analysis.R ==="
Rscript analysis/meta_analysis.R

echo
echo "=== 4/6  compare_results.py ==="
# COMPARE_ARGS is deliberately unquoted so that it splits into separate options.
# shellcheck disable=SC2086
if ! "$PYTHON" analysis/compare_results.py "$ref" outputs/results.json ${COMPARE_ARGS:-}; then
  echo "ERROR: the regenerated outputs/results.json differs from the deposited file (see the DIFF lines above)." >&2
  exit 1
fi

echo
echo "=== 5/6  prisma_figure.py ==="
"$PYTHON" analysis/prisma_figure.py

echo
echo "=== 6/6  rob_figure.py ==="
"$PYTHON" analysis/rob_figure.py

echo
echo "Done. The regenerated files are in outputs/."
