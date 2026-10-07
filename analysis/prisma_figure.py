#!/usr/bin/env python3
"""
Figure 1 - PRISMA 2020 flow diagram.

Systematic review: "Perioperative Management of Biologic and Targeted Synthetic
DMARDs in Patients with Psoriasis and Psoriatic Arthritis Undergoing Orthopedic
Surgery."

This script is the single reproducible source for Figure 1. It reads the
authoritative record counts from ``refined data pull/prisma_counts.json`` and the
authoritative flow *structure* from ``refined data pull/prisma_flow_final.mmd``
(the mermaid file is not rendered here - mmdc is unavailable - but its box/arrow
topology is reproduced faithfully in matplotlib).

No figure title is drawn. The two strips across the top are the PRISMA 2020
column headers, not a title; the figure caption lives in the manuscript text.

Outputs (300 dpi):
    manuscript/v1/figures/Figure1_PRISMA.png
    manuscript/v1/figures/Figure1_PRISMA.pdf

Only matplotlib + numpy are used (no external assets).

Run:  python3 analysis/prisma_figure.py
"""

from __future__ import annotations

import itertools
import json
import os

import matplotlib

matplotlib.use("Agg")  # headless / reproducible
import matplotlib.pyplot as plt
from matplotlib.patches import FancyBboxPatch

# --------------------------------------------------------------------------- #
# Paths                                                                        #
# --------------------------------------------------------------------------- #
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
COUNTS_JSON = os.path.join(ROOT, "data", "prisma_counts.json")
OUT_DIR = os.path.join(ROOT, "outputs", "figures")
OUT_PNG = os.path.join(OUT_DIR, "Figure1_PRISMA.png")
OUT_PDF = os.path.join(OUT_DIR, "Figure1_PRISMA.pdf")

# --------------------------------------------------------------------------- #
# Load authoritative counts                                                    #
# --------------------------------------------------------------------------- #
with open(COUNTS_JSON, "r", encoding="utf-8") as fh:
    C = json.load(fh)

ident = C["identification"]
dedup = C["deduplication"]
screen = C["screening"]
ft = C["full_text_screening"]

# Identification
pubmed = ident["per_database"]["pubmed"]                 # 179
embase = ident["per_database"]["embase"]                 # 296
central = ident["per_database"]["cochrane_central"]      # 112
cdsr = ident["per_database"]["cochrane_cdsr"]            # 2
total_records = ident["total_records"]                   # 589

dups = dedup["duplicates_removed"]                        # 60
records_after_dedup = dedup["records_after_dedup"]       # 529

# Screening (title / abstract)
records_screened = screen["records_screened"]            # 529
exclude_ta = screen["exclude_total"]                     # 408

# Retrieval / full text
sought = ft["reports_sought_for_retrieval"]              # 121
not_retrieved = ft["reports_not_retrieved"]              # 16
nr_nofull = ft["reports_not_retrieved_breakdown"]["on_no_fulltext_list"]      # 14
nr_unlisted = ft["reports_not_retrieved_breakdown"]["unlisted_missing_flag_PI"]  # 2
retrieved = ft["reports_retrieved_from_databases"]       # 103
hand_search = ft["hand_search_records"]                  # 4
assessed = ft["reports_assessed_for_eligibility"]        # 107

rexcl_total = ft["reports_excluded_with_reasons"]["total"]           # 91
r = ft["reports_excluded_with_reasons"]["by_reason"]
r_exposure = r["wrong_exposure"]                         # 52
r_population = r["wrong_population"]                      # 14
r_context = r["wrong_context_nonortho"]                  # 12
r_background = r["background_review"]                     # 12
r_english = r["not_english"]                             # 1

included = ft["studies_included"]                         # 12
awaiting = ft["ongoing_or_awaiting_classification"]["conference_or_registry_among_assessed"]  # 4
registry_stubs = ft["ongoing_or_awaiting_classification"]["trial_registry_stubs"]             # 2
ongoing_total = ft["ongoing_or_awaiting_classification"]["total"]                              # 6

# --------------------------------------------------------------------------- #
# Sanity checks - the figure must never drift from the source JSON             #
# --------------------------------------------------------------------------- #
assert pubmed + embase + central + cdsr == total_records, "database sum != 589"
assert total_records - dups == records_after_dedup == records_screened, "dedup id"
assert records_screened - exclude_ta == sought, "screen id (529-408=121)"
assert nr_nofull + nr_unlisted == not_retrieved, "not-retrieved breakdown (14+2=16)"
assert retrieved + not_retrieved + registry_stubs == sought, "sought id (103+16+2=121)"
assert retrieved + hand_search == assessed, "assessed sources (103+4=107)"
assert included + rexcl_total + awaiting == assessed, "assessed split (12+91+4=107)"
assert (r_exposure + r_population + r_context + r_background + r_english
        == rexcl_total), "reasons sum != 91"
# ongoing_total (6) is the sum of the two records-pending groups. Both groups are
# drawn in their own boxes ("Awaiting classification, n = 4" and "Trial registry /
# ongoing, n = 2"), so the 6 is validated here but deliberately NOT rendered: a
# combined "6" printed beside the included count reads as though six further
# studies were pending inclusion, which is not what it means.
assert awaiting + registry_stubs == ongoing_total, "ongoing total (4+2=6)"

# --------------------------------------------------------------------------- #
# Palette (neutral, professional; black text; very-light fills, thin borders)  #
# --------------------------------------------------------------------------- #
INK = "#111418"          # box / label text
MAIN_FILL = "#eef3fb"    # main-flow (identification -> included) boxes
MAIN_EDGE = "#2f4f8f"
EXCL_FILL = "#f4f5f7"    # exclusions / records removed (neutral gray)
EXCL_EDGE = "#8f959e"
OTHER_FILL = "#eef3fb"   # identification via other methods
OTHER_EDGE = "#2f4f8f"
INCL_FILL = "#eaf5ec"    # final included studies (subtle green emphasis)
INCL_EDGE = "#2f7d3a"
ARROW = "#333a42"
BAND_A = "#f4f7fb"       # phase background band (alt 1)
BAND_B = "#ffffff"       # phase background band (alt 2)
HDR_FILL = "#e6ecf4"     # column-header strip
NOTE = "#5a6169"         # small arrow-flow annotations

# --------------------------------------------------------------------------- #
# Figure / axes  (data coordinate system 0..100 x, 0..105 y)                   #
# --------------------------------------------------------------------------- #
fig, ax = plt.subplots(figsize=(11.0, 13.6), dpi=300)
ax.set_xlim(0, 100)
ax.set_ylim(0, 105)
ax.axis("off")
ax.set_aspect("auto")

FS_TITLE = 11.0   # box headline
FS_SUB = 9.2      # box detail lines
FS_HDR = 12.0     # column headers
FS_PHASE = 12.5   # rotated phase labels
FS_NOTE = 9.0     # arrow flow counts

# Every rectangle drawn, with the text it is required to contain. Checked at the
# end so a label can never silently spill out of its box or collide with another.
LAYOUT = []

# --------------------------------------------------------------------------- #
# Phase background bands + rotated phase labels (far left)                     #
# --------------------------------------------------------------------------- #
# (label, y_low, y_high, fill)
PHASES = [
    ("Identification", 73.5, 96.5, BAND_A),
    ("Screening",      40.5, 73.5, BAND_B),
    ("Eligibility",    14.5, 40.5, BAND_A),
    ("Included",        0.5, 14.5, BAND_B),
]
for label, y0, y1, fill in PHASES:
    ax.add_patch(
        plt.Rectangle((0.5, y0), 99.0, y1 - y0, facecolor=fill,
                      edgecolor="none", zorder=0)
    )
    ax.text(4.6, (y0 + y1) / 2.0, label, rotation=90, ha="center",
            va="center", fontsize=FS_PHASE, fontweight="bold",
            color="#3b424b", zorder=2)
# thin left rule separating phase labels from the flow
ax.plot([9.2, 9.2], [0.5, 96.5], color="#c9ced6", lw=1.0, zorder=1)

# --------------------------------------------------------------------------- #
# Column header strips (PRISMA 2020 column headers, not a figure title)        #
# --------------------------------------------------------------------------- #
def header(name, cx, y0, y1, x0, x1, text):
    ax.add_patch(
        FancyBboxPatch((x0, y0), x1 - x0, y1 - y0,
                       boxstyle="round,pad=0,rounding_size=1.2",
                       facecolor=HDR_FILL, edgecolor="#b9c2cf", lw=1.0,
                       zorder=2)
    )
    t = ax.text(cx, (y0 + y1) / 2.0, text, ha="center", va="center",
                fontsize=FS_HDR, fontweight="bold", color=INK, zorder=3)
    LAYOUT.append(dict(name=name, kind="header", x0=x0, x1=x1, y0=y0, y1=y1,
                       texts=[t]))


HDR_Y0, HDR_Y1 = 96.8, 103.8
header("hdr-databases", 44.75, HDR_Y0, HDR_Y1, 10.5, 79.0,
       "Identification of studies via databases and registers")
header("hdr-other", 90.0, HDR_Y0, HDR_Y1, 80.5, 99.5,
       "Identification of\nstudies via\nother methods")

# --------------------------------------------------------------------------- #
# Box helper                                                                    #
# --------------------------------------------------------------------------- #
def box(name, cx, cy, w, h, title, sub=None, fill=MAIN_FILL, edge=MAIN_EDGE):
    """Draw a labeled rectangle centered at (cx, cy)."""
    ax.add_patch(
        FancyBboxPatch(
            (cx - w / 2.0, cy - h / 2.0), w, h,
            boxstyle="round,pad=0,rounding_size=0.9",
            facecolor=fill, edgecolor=edge, lw=1.3, zorder=4,
        )
    )
    sub = sub or []
    # a title may span multiple bold lines (split on newline)
    lines = [(t, True) for t in title.split("\n")] + [(s, False) for s in sub]
    n = len(lines)
    step = 2.3
    top = cy + (n - 1) * step / 2.0
    texts = []
    for i, (txt, is_title) in enumerate(lines):
        texts.append(ax.text(
            cx, top - i * step, txt, ha="center", va="center",
            fontsize=FS_TITLE if is_title else FS_SUB,
            fontweight="bold" if is_title else "normal",
            color=INK, zorder=5,
        ))
    LAYOUT.append(dict(name=name, kind="box", x0=cx - w / 2.0, x1=cx + w / 2.0,
                       y0=cy - h / 2.0, y1=cy + h / 2.0, texts=texts))


# --------------------------------------------------------------------------- #
# Arrow helper (orthogonal multi-segment; arrowhead at final point)            #
# --------------------------------------------------------------------------- #
def arrow(pts, color=ARROW, lw=1.4):
    xs = [p[0] for p in pts]
    ys = [p[1] for p in pts]
    if len(pts) > 2:
        ax.plot(xs[:-1], ys[:-1], color=color, lw=lw, solid_capstyle="round",
                zorder=3)
    ax.annotate(
        "", xy=pts[-1], xytext=pts[-2],
        arrowprops=dict(arrowstyle="-|>", color=color, lw=lw,
                        shrinkA=0, shrinkB=0, mutation_scale=15),
        zorder=3,
    )


# --------------------------------------------------------------------------- #
# Box coordinates  (cx, cy, w, h)                                              #
# --------------------------------------------------------------------------- #
X_MAIN = 27.0     # main flow spine
X_EXCL = 63.0     # exclusion / removed boxes
W_EXCL = 32       # exclusion-column box width (fits the longest reason line)
X_STUB = 44.0     # shared vertical stub for the branching arrows
X_EXCL_L = X_EXCL - W_EXCL / 2.0   # left edge of the exclusion column
X_OTHER = 90.0    # identification via other methods

# --- Identification --------------------------------------------------------- #
box("identified", X_MAIN, 85.0, 27, 18,
    f"Records identified\n(n = {total_records})",
    [f"PubMed (n = {pubmed})",
     f"Embase (n = {embase})",
     f"Cochrane CENTRAL (n = {central})",
     f"Cochrane CDSR (n = {cdsr})"])

box("duplicates", X_EXCL, 86.0, W_EXCL, 10,
    "Records removed\nbefore screening",
    [f"Duplicate records removed (n = {dups})"],
    fill=EXCL_FILL, edge=EXCL_EDGE)

box("hand-search", X_OTHER, 85.0, 19, 12,
    f"Hand-searched\nrecords (n = {hand_search})",
    ["Citation searching"],
    fill=OTHER_FILL, edge=OTHER_EDGE)

# --- Screening (title / abstract) ------------------------------------------ #
box("screened", X_MAIN, 67.5, 27, 8,
    f"Records screened\n(n = {records_screened})")

box("excluded-ta", X_EXCL, 67.5, W_EXCL, 9,
    f"Records excluded\n(n = {exclude_ta})",
    ["Title / abstract screening"],
    fill=EXCL_FILL, edge=EXCL_EDGE)

box("sought", X_MAIN, 52.0, 27, 8,
    f"Reports sought for\nretrieval (n = {sought})")

box("not-retrieved", X_EXCL, 56.5, W_EXCL, 11,
    f"Reports not retrieved\n(n = {not_retrieved})",
    [f"No full text available (n = {nr_nofull})",
     f"Unlisted / missing (n = {nr_unlisted})"],
    fill=EXCL_FILL, edge=EXCL_EDGE)

box("registry-stubs", X_EXCL, 46.0, W_EXCL, 8,
    f"Trial registry / ongoing\n(n = {registry_stubs})",
    ["Registry stubs, no full report"],
    fill=EXCL_FILL, edge=EXCL_EDGE)

# --- Eligibility (full text) ------------------------------------------------ #
box("assessed", X_MAIN, 36.0, 27, 8,
    f"Reports assessed for\neligibility (n = {assessed})")

box("excluded-reasons", X_EXCL, 26.0, W_EXCL, 18,
    f"Reports excluded, with\nreasons (n = {rexcl_total})",
    [f"Wrong exposure (n = {r_exposure})",
     f"Wrong population (n = {r_population})",
     f"Wrong context, non-orthopedic (n = {r_context})",
     f"Background / review article (n = {r_background})",
     f"Not in English (n = {r_english})"],
    fill=EXCL_FILL, edge=EXCL_EDGE)

box("awaiting", X_EXCL, 8.5, W_EXCL, 10,
    f"Awaiting classification\n(n = {awaiting})",
    ["Conference abstracts", "(defer to full publication)"],
    fill=EXCL_FILL, edge=EXCL_EDGE)

# --- Included --------------------------------------------------------------- #
# Only the included count goes in this box. The records still pending are shown
# in their own boxes ("Awaiting classification" and "Trial registry / ongoing")
# so that nothing beside the included count can be read as a pending inclusion.
box("included", X_MAIN, 8.5, 27, 8,
    f"Studies included in\nreview (n = {included})",
    fill=INCL_FILL, edge=INCL_EDGE)

# --------------------------------------------------------------------------- #
# Arrows (topology follows prisma_flow_final.mmd)                              #
# --------------------------------------------------------------------------- #
# spine
arrow([(X_MAIN, 76.0), (X_MAIN, 71.5)])                 # ident -> screened
arrow([(X_MAIN, 63.5), (X_MAIN, 56.0)])                 # screened -> sought
arrow([(X_MAIN, 48.0), (X_MAIN, 40.0)])                 # sought -> assessed
arrow([(X_MAIN, 32.0), (X_MAIN, 12.5)])                 # assessed -> included

# ident -> dups
arrow([(40.5, 85.0), (X_STUB, 85.0), (X_STUB, 86.0), (X_EXCL_L, 86.0)])
# screened -> excluded (t/a)
arrow([(40.5, 67.5), (X_EXCL_L, 67.5)])
# sought -> not retrieved  &  sought -> registry (shared vertical stub)
arrow([(40.5, 52.0), (X_STUB, 52.0), (X_STUB, 56.5), (X_EXCL_L, 56.5)])
arrow([(40.5, 52.0), (X_STUB, 52.0), (X_STUB, 46.0), (X_EXCL_L, 46.0)])
# assessed -> excluded-with-reasons  &  assessed -> awaiting (shared stub)
arrow([(40.5, 34.5), (X_STUB, 34.5), (X_STUB, 26.0), (X_EXCL_L, 26.0)])
arrow([(40.5, 34.5), (X_STUB, 34.5), (X_STUB, 8.5), (X_EXCL_L, 8.5)])

# other methods: hand-search -> assessed (down far-right, into assessed's right)
arrow([(X_OTHER, 79.0), (X_OTHER, 38.0), (40.5, 38.0)])

# --------------------------------------------------------------------------- #
# Flow-count annotations that make 121 -> 107 transparent (103 + 4 = 107)      #
# --------------------------------------------------------------------------- #
ann_retrieved = ax.text(29.0, 44.0, f"n = {retrieved}\nretrieved", ha="left",
                        va="center", fontsize=FS_NOTE, style="italic",
                        color=NOTE, zorder=5, linespacing=1.1)
ann_hand = ax.text(86.0, 41.5, f"n = {hand_search}", ha="center", va="center",
                   fontsize=FS_NOTE, style="italic", color=NOTE, zorder=5)

# --------------------------------------------------------------------------- #
# Layout self-check                                                             #
#   1. every label sits fully inside its own box, with clearance                #
#   2. no two boxes overlap                                                     #
#   3. free-standing flow annotations do not land on top of a box               #
# --------------------------------------------------------------------------- #
def check_layout(free_texts, pad_pt=4.0):
    fig.canvas.draw()
    rend = fig.canvas.get_renderer()
    pad = pad_pt * fig.dpi / 72.0
    problems = []

    rects = {}
    for item in LAYOUT:
        x0, y0 = ax.transData.transform((item["x0"], item["y0"]))
        x1, y1 = ax.transData.transform((item["x1"], item["y1"]))
        rects[item["name"]] = (min(x0, x1), min(y0, y1), max(x0, x1), max(y0, y1))
        rx0, ry0, rx1, ry1 = rects[item["name"]]
        for t in item["texts"]:
            b = t.get_window_extent(rend)
            dx = max((rx0 + pad) - b.x0, b.x1 - (rx1 - pad))
            dy = max((ry0 + pad) - b.y0, b.y1 - (ry1 - pad))
            if dx > 0 or dy > 0:
                problems.append(
                    f"label overflows '{item['name']}': {t.get_text()!r} "
                    f"(dx {dx * 72.0 / fig.dpi:+.1f} pt, "
                    f"dy {dy * 72.0 / fig.dpi:+.1f} pt)"
                )

    for a, b in itertools.combinations(
            [i for i in LAYOUT if i["kind"] == "box"], 2):
        if (a["x0"] < b["x1"] and b["x0"] < a["x1"]
                and a["y0"] < b["y1"] and b["y0"] < a["y1"]):
            problems.append(f"boxes overlap: '{a['name']}' and '{b['name']}'")

    for t in free_texts:
        b = t.get_window_extent(rend)
        for nm, (rx0, ry0, rx1, ry1) in rects.items():
            if b.x0 < rx1 and rx0 < b.x1 and b.y0 < ry1 and ry0 < b.y1:
                problems.append(
                    f"annotation {t.get_text()!r} overlaps '{nm}'")

    if problems:
        raise AssertionError(
            "PRISMA layout check failed:\n  " + "\n  ".join(problems))
    return len(LAYOUT)


n_rects = check_layout([ann_retrieved, ann_hand])

# --------------------------------------------------------------------------- #
# Export                                                                        #
# --------------------------------------------------------------------------- #
os.makedirs(OUT_DIR, exist_ok=True)
fig.savefig(OUT_PNG, dpi=300, bbox_inches="tight", pad_inches=0.15,
            facecolor="white")
fig.savefig(OUT_PDF, bbox_inches="tight", pad_inches=0.15, facecolor="white")
plt.close(fig)

print("PRISMA identity checks passed.")
print(f"  identified {total_records} = {pubmed}+{embase}+{central}+{cdsr}")
print(f"  after dedup {records_after_dedup} ; screened {records_screened}")
print(f"  sought {sought} = retrieved {retrieved} + not-retrieved {not_retrieved}"
      f" + registry {registry_stubs}")
print(f"  assessed {assessed} = retrieved {retrieved} + hand-search {hand_search}")
print(f"  assessed {assessed} = included {included} + excluded {rexcl_total}"
      f" + awaiting {awaiting}")
print(f"  pending records {ongoing_total} = awaiting {awaiting} + registry"
      f" {registry_stubs} (checked, shown as two separate boxes, never as one"
      f" total beside the included count)")
print(f"Layout check passed for {n_rects} rectangles: no label overflows its "
      f"box, no boxes overlap, no annotation sits on a box.")
print("Wrote:")
print(f"  {OUT_PNG}")
print(f"  {OUT_PDF}")
