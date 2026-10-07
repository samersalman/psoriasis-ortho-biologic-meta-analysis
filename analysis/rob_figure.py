#!/usr/bin/env python3
"""
Reproducible build script for the risk-of-bias figures of the systematic review

    "Perioperative Management of Biologic and Targeted Synthetic DMARDs in
     Patients with Psoriasis and Psoriatic Arthritis Undergoing Orthopedic
     Surgery."

Outputs
-------
ROBINS-I traffic light, 8 non-randomised cohort studies (v1/v5 Figure 2;
carried into v6 as supplementary Figure S1):
    manuscript/v1/figures/Figure2_RoB.png   (300 dpi)
    manuscript/v1/figures/Figure2_RoB.pdf
    Panel A: robvis-style traffic-light plot (studies x D1-D7 + Overall).
    Panel B: weighted/summary stacked bar (distribution of judgements per domain).
    No title is drawn in the image; the caption lives in the manuscript text.

JBI critical appraisal, 4 descriptive studies (v1 Figure S1; not used in v6,
whose JBI figure is the BioRender version):
    manuscript/v1/supplement/FigureS1_JBI.png (300 dpi)
    manuscript/v1/supplement/FigureS1_JBI.pdf
    Panel A: JBI case-series checklist (Q1-Q10) for Kawakami 2016, Fabiano 2014.
    Panel B: JBI case-report checklist (Q1-Q8) for Koga 2025, Kunimi 2018.

Inputs
------
    rob/robins_i_assessments.csv
    rob/jbi_assessments.csv

Judgement tokens are parsed EXACTLY as they appear in the CSV. If an unknown
token is encountered the script aborts rather than guessing a colour.

Dependencies: matplotlib only (CSV parsing / wrapping via the standard library).
Run:  python3 analysis/rob_figure.py
"""

import csv
import os
import sys
import textwrap

import matplotlib

matplotlib.use("Agg")  # headless / reproducible
import matplotlib.pyplot as plt
from matplotlib.patches import Circle, Rectangle

# --------------------------------------------------------------------------- #
# Paths
# --------------------------------------------------------------------------- #
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ROB_DIR = os.path.join(ROOT, "rob")
FIG_DIR = os.path.join(ROOT, "outputs", "figures")
SUP_DIR = os.path.join(ROOT, "outputs", "supplement")

ROBINS_CSV = os.path.join(ROB_DIR, "robins_i_assessments.csv")
JBI_CSV = os.path.join(ROB_DIR, "jbi_assessments.csv")

FIG2_BASE = os.path.join(FIG_DIR, "Figure2_RoB")
FIGS1_BASE = os.path.join(SUP_DIR, "FigureS1_JBI")

# --------------------------------------------------------------------------- #
# Colour / glyph semantics
# --------------------------------------------------------------------------- #
# ROBINS-I judgement -> (fill colour, glyph, glyph colour)
# Conventional RoB semantics; the green->yellow->orange->dark-red ramp also
# separates by luminance, which helps colour-vision-deficient readers.
ROBINS_STYLE = {
    "Low":            ("#2E9C57", "+",       "white"),  # green
    "Moderate":       ("#F2C31D", "?",       "black"),  # yellow
    "Serious":        ("#E67425", "−",  "white"),  # orange, minus sign
    "Critical":       ("#8E1B1B", "×",  "white"),  # dark red, x
    "No information": ("#9E9E9E", "?",       "white"),  # grey
}
ROBINS_ORDER = ["Low", "Moderate", "Serious", "Critical", "No information"]

# JBI answer -> (fill colour, glyph, glyph colour)
JBI_STYLE = {
    "Yes":     ("#2E9C57", "+",      "white"),  # green
    "No":      ("#C0392B", "−", "white"),  # red
    "Unclear": ("#F2C31D", "?",      "black"),  # yellow
    "NA":      ("#9E9E9E", "",       "white"),  # grey (not applicable)
}
JBI_ORDER = ["Yes", "No", "Unclear", "NA"]

# JBI overall appraisal (quality tier) -> style, reusing the same
# good / some-concerns semantics (green = high quality, yellow = moderate).
JBI_OVERALL_STYLE = {
    "high":     ("#2E9C57", "+", "white"),
    "moderate": ("#F2C31D", "?", "black"),
    "low":      ("#F2C31D", "?", "black"),
}
JBI_TIER_PHRASE = {"high": "high", "moderate": "moderate", "low": "low–moderate"}

DOMAIN_COLS = ["D1", "D2", "D3", "D4", "D5", "D6", "D7", "Overall"]

ROBINS_DOMAIN_LABELS = {
    "D1": "D1 Confounding",
    "D2": "D2 Selection of participants into the study",
    "D3": "D3 Classification of interventions",
    "D4": "D4 Deviations from intended interventions",
    "D5": "D5 Missing data",
    "D6": "D6 Measurement of outcomes",
    "D7": "D7 Selection of the reported result",
}

JBI_CASE_SERIES_ITEMS = [
    "Q1 Clear inclusion criteria",
    "Q2 Condition measured in a standard, reliable way",
    "Q3 Valid methods to identify the condition",
    "Q4 Consecutive inclusion of participants",
    "Q5 Complete inclusion of participants",
    "Q6 Demographics clearly reported",
    "Q7 Clinical information clearly reported",
    "Q8 Outcomes / follow-up clearly reported",
    "Q9 Presenting site(s)/clinic(s) demographics reported",
    "Q10 Statistical analysis appropriate",
]

JBI_CASE_REPORT_ITEMS = [
    "Q1 Patient demographics clearly described",
    "Q2 History clearly described as a timeline",
    "Q3 Current clinical condition clearly described",
    "Q4 Diagnostic tests / assessment results described",
    "Q5 Intervention / treatment clearly described",
    "Q6 Post-intervention clinical condition described",
    "Q7 Adverse / unanticipated events described",
    "Q8 Case report provides takeaway lessons",
]


# --------------------------------------------------------------------------- #
# Data loading + validation
# --------------------------------------------------------------------------- #
def load_robins(path):
    """Return list of dicts with study_label + D1..D7 + Overall; validate tokens."""
    rows = []
    with open(path, newline="", encoding="utf-8") as fh:
        for r in csv.DictReader(fh):
            rec = {"study_label": r["study_label"].strip(),
                   "study_id": r["study_id"].strip()}
            for col in DOMAIN_COLS:
                tok = r[col].strip()
                if tok not in ROBINS_STYLE:
                    sys.exit(f"[ABORT] Unexpected ROBINS-I token '{tok}' for "
                             f"{rec['study_label']} column {col}. "
                             f"Allowed: {list(ROBINS_STYLE)}")
                rec[col] = tok
            rows.append(rec)
    return rows


def _quality_tier(appraisal):
    """Map an 'Include - <tier> quality' string to high / moderate / low."""
    a = appraisal.lower()
    if "high" in a:
        return "high"
    if "low" in a:          # e.g. 'low-to-moderate quality'
        return "low"
    return "moderate"


def load_jbi(path):
    """Return two lists (case_series, case_report) of validated study records."""
    series, report = [], []
    with open(path, newline="", encoding="utf-8") as fh:
        for r in csv.DictReader(fh):
            ctype = r["checklist_type"].strip()
            n_items = 10 if ctype == "case_series" else 8
            items = []
            for i in range(1, n_items + 1):
                tok = r[f"Q{i}"].strip()
                if tok not in JBI_STYLE:
                    sys.exit(f"[ABORT] Unexpected JBI token '{tok}' for "
                             f"{r['study_label']} item Q{i}. "
                             f"Allowed: {list(JBI_STYLE)}")
                items.append(tok)
            rec = {"study_label": r["study_label"].strip(),
                   "items": items,
                   "n_yes": r["n_yes"].strip(),
                   "n_total": r["n_total"].strip(),
                   "appraisal": r["overall_appraisal"].strip(),
                   "tier": _quality_tier(r["overall_appraisal"])}
            (series if ctype == "case_series" else report).append(rec)
    return series, report


# --------------------------------------------------------------------------- #
# Drawing primitives
# --------------------------------------------------------------------------- #
def draw_traffic_light(ax, study_labels, col_labels, cell_styles,
                       radius=0.40, gap_before_last=True,
                       glyph_fs=12, col_fs=11, row_fs=11,
                       header_y_pad=0.95, right_text=None, right_text_fs=9):
    """
    Draw a robvis-style traffic-light grid on `ax` (equal aspect -> round dots).

    cell_styles : 2D list [row][col] of (fill, glyph, glyph_colour) tuples.
    right_text  : optional list[str], one short annotation per row (right side).
    """
    n_rows, n_cols = len(study_labels), len(col_labels)

    # column x-centres (extra gap before the final 'Overall' column)
    xs, x = [], 1.0
    for j in range(n_cols):
        if gap_before_last and j == n_cols - 1:
            x += 0.6
        xs.append(x)
        x += 1.0

    ys = [n_rows - i for i in range(n_rows)]           # first study at top
    x_left, x_right = xs[0] - 0.65, xs[-1] + 0.65

    # alternating row shading
    for i in range(n_rows):
        if i % 2 == 0:
            ax.add_patch(Rectangle((x_left, ys[i] - 0.5), x_right - x_left, 1.0,
                                   facecolor="#F4F4F4", edgecolor="none", zorder=0))

    # separator before the Overall column
    if gap_before_last and n_cols >= 2:
        sep_x = (xs[-2] + xs[-1]) / 2.0
        ax.plot([sep_x, sep_x], [ys[-1] - 0.5, ys[0] + 0.5],
                color="#BBBBBB", lw=0.8, zorder=1)

    # circles + glyphs
    for i in range(n_rows):
        for j in range(n_cols):
            fill, glyph, gcol = cell_styles[i][j]
            ax.add_patch(Circle((xs[j], ys[i]), radius, facecolor=fill,
                                 edgecolor="white", linewidth=1.3, zorder=2))
            if glyph:
                ax.text(xs[j], ys[i], glyph, ha="center", va="center", color=gcol,
                        fontsize=glyph_fs, fontweight="bold", zorder=3)

    # column headers
    for j in range(n_cols):
        ax.text(xs[j], ys[0] + header_y_pad, col_labels[j], ha="center",
                va="bottom", fontsize=col_fs, fontweight="bold")

    # row labels (left)
    row_label_x = x_left - 0.2
    for i in range(n_rows):
        ax.text(row_label_x, ys[i], study_labels[i], ha="right", va="center",
                fontsize=row_fs)

    # optional right-hand annotations
    right_edge = x_right + 0.3
    if right_text is not None:
        for i in range(n_rows):
            ax.text(x_right + 0.55, ys[i], right_text[i], ha="left", va="center",
                    fontsize=right_text_fs, color="#333333", clip_on=False)
        right_edge = x_right + 0.75 + 0.145 * max(len(t) for t in right_text)

    ax.set_xlim(row_label_x - 3.2, right_edge)
    ax.set_ylim(ys[-1] - 0.9, ys[0] + header_y_pad + 0.8)
    ax.set_aspect("equal")
    ax.axis("off")
    return xs, ys, x_left, x_right


def draw_summary_bar(ax, domain_codes, counts_by_domain, order, style, total,
                     label_fs=9, code_fs=10):
    """Horizontal stacked bars: one per domain, segments = judgement distribution."""
    n = len(domain_codes)
    ys = [n - i for i in range(n)]                      # top -> bottom
    for i, code in enumerate(domain_codes):
        left = 0.0
        counts = counts_by_domain[code]
        for judg in order:
            c = counts.get(judg, 0)
            if c == 0:
                continue
            pct = 100.0 * c / total
            fill, _, gcol = style[judg]
            ax.barh(ys[i], pct, left=left, height=0.62, color=fill,
                    edgecolor="white", linewidth=1.0, zorder=2)
            if pct >= 9.0:
                ax.text(left + pct / 2.0, ys[i], f"{pct:g}%", ha="center",
                        va="center", fontsize=label_fs, color=gcol,
                        fontweight="bold", zorder=3)
            left += pct

    ax.set_yticks(ys)
    ax.set_yticklabels(domain_codes, fontsize=code_fs, fontweight="bold")
    ax.set_ylim(0.4, n + 0.6)
    ax.set_xlim(0, 100)
    ax.set_xticks([0, 20, 40, 60, 80, 100])
    ax.set_xlabel("Distribution of judgements across studies (%)", fontsize=10)
    ax.tick_params(axis="y", length=0)
    ax.tick_params(axis="x", labelsize=9)
    for spine in ("top", "right", "left"):
        ax.spines[spine].set_visible(False)
    ax.spines["bottom"].set_color("#888888")
    ax.set_axisbelow(True)


def draw_marker_legend(fig, rect, order, style, title,
                       marker_size=210, label_fs=10.5, glyph_fs=9, title_fs=10.5):
    """Manually laid-out legend of coloured circles + glyphs + labels (centred)."""
    ax = fig.add_axes(rect)
    ax.set_xlim(0, 1)
    ax.set_ylim(0, 1)
    ax.axis("off")
    ax_w_in = rect[2] * fig.get_size_inches()[0]
    char_w = label_fs * 0.60 / (ax_w_in * 72.0)         # axes-fraction per char
    marker_w, pad, gap = 0.016, 0.006, 0.028
    widths = [marker_w + pad + len(j) * char_w for j in order]
    total = sum(widths) + gap * (len(order) - 1)
    x, y = (1.0 - total) / 2.0, 0.42
    for judg, w in zip(order, widths):
        fill, glyph, gcol = style[judg]
        mx = x + marker_w * 0.5
        ax.scatter([mx], [y], s=marker_size, c=fill, edgecolors="white",
                   linewidths=1.2, zorder=2)
        if glyph:
            ax.text(mx, y, glyph, ha="center", va="center", color=gcol,
                    fontsize=glyph_fs, fontweight="bold", zorder=3)
        ax.text(x + marker_w + pad, y, judg, ha="left", va="center",
                fontsize=label_fs, zorder=2)
        x += w + gap
    ax.text(0.5, 0.93, title, ha="center", va="center", fontsize=title_fs,
            fontweight="bold")
    return ax


# --------------------------------------------------------------------------- #
# Figure 2  (ROBINS-I)
# --------------------------------------------------------------------------- #
def build_figure2(robins):
    study_labels = [r["study_label"] for r in robins]
    total = len(robins)
    cell_styles = [[ROBINS_STYLE[r[c]] for c in DOMAIN_COLS] for r in robins]

    counts_by_domain = {c: {} for c in DOMAIN_COLS}
    for r in robins:
        for c in DOMAIN_COLS:
            counts_by_domain[c][r[c]] = counts_by_domain[c].get(r[c], 0) + 1

    # No figure title is drawn in the image: the title and caption belong in the
    # manuscript text. Panel geometry is pinned in inches from the bottom of the
    # canvas, so the panels are unaffected by the canvas height that the removed
    # title used to occupy.
    FIG_W, FIG_H = 9.2, 9.85
    PANEL_TOP_IN, PANEL_BOT_IN = 9.231, 2.397
    LEGEND_Y_IN, LEGEND_H_IN = 1.377, 0.561
    FOOTNOTE_Y_IN = 0.1224

    fig = plt.figure(figsize=(FIG_W, FIG_H))
    gs = fig.add_gridspec(2, 1, height_ratios=[1.18, 1.0], hspace=0.22,
                          left=0.095, right=0.965,
                          top=PANEL_TOP_IN / FIG_H, bottom=PANEL_BOT_IN / FIG_H)
    ax_tl = fig.add_subplot(gs[0])
    ax_bar = fig.add_subplot(gs[1])

    # Panel A -----------------------------------------------------------------
    draw_traffic_light(ax_tl, study_labels, DOMAIN_COLS, cell_styles,
                       radius=0.40, glyph_fs=13, col_fs=12, row_fs=11.5)
    ax_tl.text(0.0, 1.0, "A", transform=ax_tl.transAxes, fontsize=17,
               fontweight="bold", ha="left", va="top")
    ax_tl.set_title("Study-level judgements (traffic-light plot)",
                    fontsize=12, pad=14)

    # Panel B -----------------------------------------------------------------
    draw_summary_bar(ax_bar, DOMAIN_COLS, counts_by_domain, ROBINS_ORDER,
                     ROBINS_STYLE, total)
    ax_bar.text(-0.085, 1.06, "B", transform=ax_bar.transAxes, fontsize=17,
                fontweight="bold", ha="left", va="top", clip_on=False)
    ax_bar.set_title("Distribution of judgements across the 8 studies",
                     fontsize=12, pad=10)

    # Legend ------------------------------------------------------------------
    draw_marker_legend(fig, [0.05, LEGEND_Y_IN / FIG_H, 0.90, LEGEND_H_IN / FIG_H],
                       ROBINS_ORDER, ROBINS_STYLE, "Risk-of-bias judgement")

    # Footnote ----------------------------------------------------------------
    domain_defs = ("ROBINS-I domains:  "
                   + ";  ".join(ROBINS_DOMAIN_LABELS[c] for c in DOMAIN_COLS
                                if c != "Overall")
                   + ".  Overall = overall risk-of-bias judgement.")
    note2 = ("Panel B shows the distribution of the 8 studies’ judgements within "
             "each domain (unweighted; each study = 12.5%).  “Critical” and "
             "“No information” appear in the legend for completeness but were "
             "assigned to no study or domain.")
    footnote = textwrap.fill(domain_defs, width=126) + "\n" + \
        textwrap.fill(note2, width=126)
    fig.text(0.095, FOOTNOTE_Y_IN / FIG_H, footnote, ha="left", va="bottom",
             fontsize=8, color="#222222", linespacing=1.5)

    fig.savefig(FIG2_BASE + ".png", dpi=300)
    fig.savefig(FIG2_BASE + ".pdf")
    plt.close(fig)
    return counts_by_domain


# --------------------------------------------------------------------------- #
# Figure S1  (JBI)
# --------------------------------------------------------------------------- #
def _jbi_cells(records, n_items):
    labels = [r["study_label"] for r in records]
    cols = [f"Q{i}" for i in range(1, n_items + 1)] + ["Overall"]
    cell_styles, right = [], []
    for r in records:
        row = [JBI_STYLE[tok] for tok in r["items"]]
        row.append(JBI_OVERALL_STYLE[r["tier"]])        # Overall column
        cell_styles.append(row)
        right.append(f"{r['n_yes']}/{r['n_total']} · "
                     f"{JBI_TIER_PHRASE[r['tier']]}")
    return labels, cols, cell_styles, right


def build_figure_s1(series, report):
    fig = plt.figure(figsize=(12.0, 7.4))
    gs = fig.add_gridspec(2, 1, height_ratios=[1.0, 1.0], hspace=0.35,
                          left=0.11, right=0.985, top=0.872, bottom=0.315)
    ax_a = fig.add_subplot(gs[0])
    ax_b = fig.add_subplot(gs[1])

    fig.suptitle("JBI critical appraisal of descriptive studies",
                 fontsize=15, fontweight="bold", y=0.975)

    la, ca, sa, ra = _jbi_cells(series, 10)
    draw_traffic_light(ax_a, la, ca, sa, glyph_fs=12, col_fs=11, row_fs=11.5,
                       right_text=ra, right_text_fs=9.5)
    ax_a.text(0.0, 1.0, "A", transform=ax_a.transAxes, fontsize=16,
              fontweight="bold", ha="left", va="top")
    ax_a.set_title("JBI checklist for case series (10 items)", fontsize=11.5, pad=12)

    lb, cb, sb, rb = _jbi_cells(report, 8)
    draw_traffic_light(ax_b, lb, cb, sb, glyph_fs=12, col_fs=11, row_fs=11.5,
                       right_text=rb, right_text_fs=9.5)
    ax_b.text(0.0, 1.0, "B", transform=ax_b.transAxes, fontsize=16,
              fontweight="bold", ha="left", va="top")
    ax_b.set_title("JBI checklist for case reports (8 items)", fontsize=11.5, pad=12)

    # Legend ------------------------------------------------------------------
    draw_marker_legend(fig, [0.05, 0.225, 0.92, 0.05], JBI_ORDER, JBI_STYLE,
                       "Appraisal of each item")

    # Footnote ----------------------------------------------------------------
    l1 = ("Kawakami 2016 and Fabiano 2014 were appraised with the JBI critical "
          "appraisal checklist for case series; Koga 2025 and Kunimi 2018 with the "
          "JBI checklist for case reports.")
    l2 = ("Overall column = JBI appraisal decision (all four studies were included); "
          "its colour denotes the overall quality tier (green = high, yellow = "
          "moderate / low-to-moderate).  Right-hand text = Yes count · quality "
          "tier.  NA = item not applicable.")
    cs = "Case-series items — " + ";  ".join(JBI_CASE_SERIES_ITEMS) + "."
    cr = "Case-report items — " + ";  ".join(JBI_CASE_REPORT_ITEMS) + "."
    note = "\n".join(textwrap.fill(t, width=190) for t in (l1, l2, cs, cr))
    fig.text(0.11, 0.008, note, ha="left", va="bottom", fontsize=7.2,
             color="#222222", linespacing=1.45)

    fig.savefig(FIGS1_BASE + ".png", dpi=300)
    fig.savefig(FIGS1_BASE + ".pdf")
    plt.close(fig)


# --------------------------------------------------------------------------- #
# Main
# --------------------------------------------------------------------------- #
def main():
    os.makedirs(FIG_DIR, exist_ok=True)
    os.makedirs(SUP_DIR, exist_ok=True)

    robins = load_robins(ROBINS_CSV)
    series, report = load_jbi(JBI_CSV)
    print(f"Loaded {len(robins)} ROBINS-I studies, {len(series)} JBI case-series, "
          f"{len(report)} JBI case-report studies.")

    counts = build_figure2(robins)
    build_figure_s1(series, report)

    print("\nROBINS-I study x Overall:")
    for r in robins:
        print(f"  {r['study_label']:<18} {r['Overall']}")
    print("\nPer-domain judgement counts (n of 8):")
    for c in DOMAIN_COLS:
        dist = ", ".join(f"{k}={counts[c][k]}" for k in ROBINS_ORDER
                         if counts[c].get(k))
        print(f"  {c:<8} {dist}")

    print("\nJBI overall appraisals:")
    for r in series + report:
        print(f"  {r['study_label']:<16} {r['n_yes']}/{r['n_total']}  "
              f"{r['appraisal']}")

    print("\nWrote:")
    for p in (FIG2_BASE + ".png", FIG2_BASE + ".pdf",
              FIGS1_BASE + ".png", FIGS1_BASE + ".pdf"):
        print(f"  {p}  ({os.path.getsize(p)} bytes)")


if __name__ == "__main__":
    main()
