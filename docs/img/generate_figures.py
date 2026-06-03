#!/usr/bin/env python3
"""Generate the schematic QC interpretation figures used throughout the t2t-flow
documentation and cookbook.

These are *illustrative schematics* — they reproduce the characteristic SHAPE of
each QC plot so readers learn to read real outputs. They are not derived from any
single pipeline run. Every figure is annotated as schematic.

Run:  python docs/img/generate_figures.py
Deps: matplotlib, numpy
"""
from __future__ import annotations

import os
import numpy as np
import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.patches import FancyBboxPatch, FancyArrowPatch

OUT = os.path.dirname(os.path.abspath(__file__))
RNG = np.random.default_rng(20240603)
SCHEMATIC = "schematic — illustrative shape, not from a specific run"


def _save(fig, name):
    path = os.path.join(OUT, name)
    fig.savefig(path, dpi=130, bbox_inches="tight", facecolor="white")
    plt.close(fig)
    print("wrote", os.path.relpath(path))


def _gauss(x, mu, sigma, amp):
    return amp * np.exp(-0.5 * ((x - mu) / sigma) ** 2)


# ---------------------------------------------------------------------------
# 1. GenomeScope2 k-mer profile (diploid, heterozygous)
# ---------------------------------------------------------------------------
def genomescope_profile():
    x = np.linspace(0, 90, 1000)
    het = _gauss(x, 22, 3.2, 0.42)          # heterozygous (haploid-coverage) peak
    hom = _gauss(x, 44, 4.0, 1.00)          # homozygous (full-coverage) peak
    rep = _gauss(x, 88, 6.0, 0.18)          # 2-copy repeat shoulder
    err = 0.9 * np.exp(-x / 2.2)            # sequencing-error k-mers near origin
    y = het + hom + rep
    y_obs = y + RNG.normal(0, 0.012, x.size)

    fig, ax = plt.subplots(figsize=(7.6, 4.6))
    ax.fill_between(x, 0, err, color="#c9c9c9", alpha=0.7, label="error k-mers")
    ax.plot(x, np.clip(y_obs, 0, None), color="#1f3b73", lw=1.6, label="observed k-mer spectrum")
    ax.plot(x, y, color="#e07b39", lw=1.8, ls="--", label="GenomeScope2 model fit")

    ax.annotate("heterozygous peak\n(haploid coverage ~22x)", xy=(22, 0.46), xytext=(8, 0.78),
                fontsize=8.5, arrowprops=dict(arrowstyle="->", color="#444"))
    ax.annotate("homozygous peak\n(diploid coverage ~44x)", xy=(44, 1.02), xytext=(50, 1.05),
                fontsize=8.5, arrowprops=dict(arrowstyle="->", color="#444"))
    ax.annotate("repeat / 2-copy shoulder", xy=(88, 0.2), xytext=(64, 0.5),
                fontsize=8.5, arrowprops=dict(arrowstyle="->", color="#444"))
    ax.text(0.98, 0.74,
            "het peak height vs hom peak\n= heterozygosity.\nTwo clear peaks => diploid.\nA single peak => low het\nor haploid/inbred.",
            transform=ax.transAxes, ha="right", va="top", fontsize=8,
            bbox=dict(boxstyle="round", fc="#fff4e6", ec="#e07b39"))

    ax.set_xlabel("k-mer multiplicity (coverage)")
    ax.set_ylabel("k-mer frequency (a.u.)")
    ax.set_title("GenomeScope2 profile — heterozygous diploid non-model genome")
    ax.set_ylim(0, 1.25)
    ax.legend(loc="upper center", fontsize=8, framealpha=0.9)
    ax.text(0.5, -0.16, SCHEMATIC, transform=ax.transAxes, ha="center", fontsize=7, color="#888")
    _save(fig, "genomescope_profile.png")


# ---------------------------------------------------------------------------
# 2 & 3. Merqury spectra-cn (good vs bad)
# ---------------------------------------------------------------------------
def _spectra_cn(ax, good: bool):
    x = np.linspace(0, 80, 800)
    # copy-number layers (stacked): read-only(0), 1-copy, 2-copy, >2-copy
    one = _gauss(x, 30, 4.5, 1.00)
    two = _gauss(x, 60, 5.0, 0.30 if good else 0.62)
    if good:
        read_only = 0.6 * np.exp(-x / 2.0)                 # only low-mult error k-mers
        more = _gauss(x, 78, 6, 0.04)
    else:
        read_only = 0.6 * np.exp(-x / 2.0) + _gauss(x, 30, 5.0, 0.45)  # missing-from-asm peak under main
        more = _gauss(x, 78, 6, 0.10)

    layers = [
        (read_only, "#222222", "read-only (0 copies in asm)"),
        (one, "#d62728", "1 copy"),
        (two, "#1f77b4", "2 copies"),
        (more, "#2ca02c", ">2 copies"),
    ]
    base = np.zeros_like(x)
    for y, c, lab in layers:
        ax.fill_between(x, base, base + y, color=c, alpha=0.85, label=lab, lw=0)
        base = base + y
    ax.set_xlim(0, 80)
    ax.set_ylim(0, 1.7)
    ax.set_xlabel("k-mer multiplicity in reads")
    ax.set_ylabel("k-mer count (a.u.)")


def merqury_spectra_good():
    fig, ax = plt.subplots(figsize=(7.0, 4.4))
    _spectra_cn(ax, good=True)
    ax.set_title("Merqury spectra-cn — GOOD assembly")
    ax.annotate("single clean 1-copy peak\nat sequencing coverage", xy=(30, 1.0), xytext=(40, 1.45),
                fontsize=8.5, arrowprops=dict(arrowstyle="->", color="#444"))
    ax.annotate("tiny read-only peak\n=> little missing sequence", xy=(8, 0.18), xytext=(2, 0.95),
                fontsize=8.5, arrowprops=dict(arrowstyle="->", color="#444"))
    ax.legend(fontsize=7.5, loc="upper right")
    ax.text(0.5, -0.17, SCHEMATIC, transform=ax.transAxes, ha="center", fontsize=7, color="#888")
    _save(fig, "merqury_spectra_cn_good.png")


def merqury_spectra_bad():
    fig, ax = plt.subplots(figsize=(7.0, 4.4))
    _spectra_cn(ax, good=False)
    ax.set_title("Merqury spectra-cn — PROBLEM assembly")
    ax.annotate("large black 'read-only' peak UNDER the\nmain peak => sequence present in reads\nbut MISSING from the assembly", xy=(30, 0.45),
                xytext=(1.5, 1.0), fontsize=8.0, arrowprops=dict(arrowstyle="->", color="#222"),
                bbox=dict(boxstyle="round", fc="#f3f3f3", ec="#999"))
    ax.annotate("inflated 2-copy (blue) peak =>\nretained haplotype duplication\n(run purge_dups)", xy=(60, 0.6),
                xytext=(43, 1.0), fontsize=8.0, arrowprops=dict(arrowstyle="->", color="#1f77b4"),
                bbox=dict(boxstyle="round", fc="#eaf3fa", ec="#1f77b4"))
    ax.legend(fontsize=7.5, loc="upper right")
    ax.text(0.5, -0.17, SCHEMATIC, transform=ax.transAxes, ha="center", fontsize=7, color="#888")
    _save(fig, "merqury_spectra_cn_bad.png")


# ---------------------------------------------------------------------------
# 4. Merqury QV scale concept
# ---------------------------------------------------------------------------
def merqury_qv_concept():
    fig, ax = plt.subplots(figsize=(8.2, 2.6))
    qmin, qmax = 20, 65
    grad = np.linspace(0, 1, 512).reshape(1, -1)
    ax.imshow(grad, extent=[qmin, qmax, 0, 1], aspect="auto",
              cmap="RdYlGn", alpha=0.85)
    for q, acc in [(20, "99%"), (30, "99.9%"), (40, "99.99%"), (50, "99.999%"), (60, "99.9999%")]:
        ax.axvline(q, color="#333", lw=0.8)
        ax.text(q, 1.06, f"Q{q}", ha="center", fontsize=9, fontweight="bold")
        ax.text(q, -0.16, acc, ha="center", fontsize=7.5, color="#333")
    ax.axvspan(qmin, 40, color="white", alpha=0.0)
    ax.annotate("needs polishing /\ncheck contamination", xy=(33, 0.5), xytext=(24.5, 1.7),
                fontsize=8, ha="center", arrowprops=dict(arrowstyle="->", color="#a00"))
    ax.annotate("typical HiFi assembly\n(Q50-Q60+)", xy=(55, 0.5), xytext=(55, 1.7),
                fontsize=8, ha="center", arrowprops=dict(arrowstyle="->", color="#070"))
    ax.set_yticks([])
    ax.set_xlim(qmin, qmax)
    ax.set_ylim(0, 1)
    ax.set_xlabel("Merqury consensus quality value (QV = -10 log10 error rate)")
    ax.set_title("Reading the Merqury QV: higher = fewer base errors")
    ax.text(0.5, -0.55, SCHEMATIC, transform=ax.transAxes, ha="center", fontsize=7, color="#888")
    _save(fig, "merqury_qv_concept.png")


# ---------------------------------------------------------------------------
# 5. BUSCO good vs over-assembled (duplicated)
# ---------------------------------------------------------------------------
def busco_good_vs_dup():
    cats = ["Complete (single)", "Complete (dup)", "Fragmented", "Missing"]
    colors = ["#3b7dd8", "#52b3d9", "#f5b041", "#cd5c5c"]
    good = [96.5, 1.0, 1.2, 1.3]
    bad = [79.0, 17.5, 2.0, 1.5]
    fig, ax = plt.subplots(figsize=(8.0, 3.0))
    rows = {"Well-curated assembly": good, "Over-assembled (uncollapsed haplotypes)": bad}
    for i, (label, vals) in enumerate(rows.items()):
        left = 0
        for v, c in zip(vals, colors):
            ax.barh(i, v, left=left, color=c, edgecolor="white")
            if v > 4:
                ax.text(left + v / 2, i, f"{v:.0f}%", va="center", ha="center",
                        color="white", fontsize=8.5, fontweight="bold")
            left += v
    ax.set_yticks(range(len(rows)))
    ax.set_yticklabels(list(rows.keys()), fontsize=9)
    ax.set_xlim(0, 100)
    ax.set_xlabel("% of BUSCO genes")
    ax.set_title("BUSCO: high Duplicated (D) => retained haplotype duplication, run purge_dups")
    handles = [plt.Rectangle((0, 0), 1, 1, color=c) for c in colors]
    ax.legend(handles, cats, ncol=4, fontsize=7.5, loc="upper center", bbox_to_anchor=(0.5, -0.28))
    ax.text(0.5, -0.55, SCHEMATIC, transform=ax.transAxes, ha="center", fontsize=7, color="#888")
    _save(fig, "busco_good_vs_dup.png")


# ---------------------------------------------------------------------------
# 6. tidk telomere density along scaffolds
# ---------------------------------------------------------------------------
def tidk_telomere():
    fig, axes = plt.subplots(3, 1, figsize=(8.0, 4.6), sharex=True)
    pos = np.linspace(0, 1, 400)
    tracks = [
        ("scaffold_1 (T2T)", True, True),
        ("scaffold_2 (T2T)", True, True),
        ("scaffold_3 (one end open)", True, False),
    ]
    for ax, (name, left_tel, right_tel) in zip(axes, tracks):
        sig = np.zeros_like(pos)
        if left_tel:
            sig += _gauss(pos, 0.0, 0.02, 1.0)
        if right_tel:
            sig += _gauss(pos, 1.0, 0.02, 1.0)
        sig += RNG.normal(0, 0.01, pos.size).clip(0)
        ax.fill_between(pos, 0, sig, color="#7b3fa0", alpha=0.85)
        ax.set_ylim(0, 1.2)
        ax.set_yticks([])
        ax.set_ylabel(name, rotation=0, ha="right", va="center", fontsize=8.5)
        if left_tel:
            ax.text(0.0, 1.05, "[telomere]", fontsize=7.5, color="#070")
        if right_tel:
            ax.text(1.0, 1.05, "[telomere]", fontsize=7.5, color="#070", ha="right")
        else:
            ax.text(1.0, 1.05, "[open end - no telomere]", fontsize=7.5, color="#a00", ha="right")
    axes[-1].set_xlabel("position along scaffold (telomeric repeat density)")
    axes[0].set_title("tidk: telomeres at BOTH ends of a scaffold = telomere-to-telomere signal")
    fig.text(0.5, -0.02, SCHEMATIC, ha="center", fontsize=7, color="#888")
    fig.tight_layout()
    _save(fig, "tidk_telomere.png")


# ---------------------------------------------------------------------------
# 7. purge_dups read-depth cutoffs
# ---------------------------------------------------------------------------
def purge_dups_cutoffs():
    x = np.linspace(0, 100, 1000)
    hap = _gauss(x, 25, 4.5, 0.55)   # haploid / heterozygous coverage
    dip = _gauss(x, 50, 5.5, 1.00)   # diploid / homozygous coverage
    y = hap + dip + 0.4 * np.exp(-x / 3)
    fig, ax = plt.subplots(figsize=(7.6, 4.2))
    ax.fill_between(x, 0, y, color="#5b8fb9", alpha=0.7)
    for cut, lab, col in [(12, "low", "#888"), (37, "mid", "#e07b39"), (75, "high", "#888")]:
        ax.axvline(cut, color=col, ls="--", lw=1.6)
        ax.text(cut, 1.3, lab, ha="center", fontsize=8.5, color=col, fontweight="bold")
    ax.annotate("haploid/heterozygous\ncoverage peak", xy=(25, 0.6), xytext=(4, 1.05),
                fontsize=8.2, arrowprops=dict(arrowstyle="->", color="#444"))
    ax.annotate("diploid/homozygous\ncoverage peak", xy=(50, 1.02), xytext=(58, 1.18),
                fontsize=8.2, arrowprops=dict(arrowstyle="->", color="#444"))
    ax.text(0.98, 0.55,
            "purge_dups flags contigs whose\nread depth sits at the haploid\npeak (between 'low' and 'mid')\nas likely haplotype duplicates.\nCheck calcuts picked the cutoffs\nat the real valleys.",
            transform=ax.transAxes, ha="right", va="top", fontsize=8,
            bbox=dict(boxstyle="round", fc="#eef5fb", ec="#5b8fb9"))
    ax.set_xlabel("read depth")
    ax.set_ylabel("contig count (a.u.)")
    ax.set_ylim(0, 1.5)
    ax.set_title("purge_dups coverage cutoffs (calcuts)")
    ax.text(0.5, -0.16, SCHEMATIC, transform=ax.transAxes, ha="center", fontsize=7, color="#888")
    _save(fig, "purge_dups_cutoffs.png")


# ---------------------------------------------------------------------------
# 8. Static DAG fallback for the mermaid diagram
# ---------------------------------------------------------------------------
def assembly_dag():
    fig, ax = plt.subplots(figsize=(9.2, 5.6))
    ax.set_xlim(0, 10)
    ax.set_ylim(0, 12)
    ax.axis("off")

    def box(x, y, w, h, text, fc):
        p = FancyBboxPatch((x, y), w, h, boxstyle="round,pad=0.04,rounding_size=0.12",
                           fc=fc, ec="#33485e", lw=1.3)
        ax.add_patch(p)
        ax.text(x + w / 2, y + h / 2, text, ha="center", va="center", fontsize=8.6, color="#13242f")

    def arrow(x1, y1, x2, y2):
        ax.add_patch(FancyArrowPatch((x1, y1), (x2, y2), arrowstyle="-|>", mutation_scale=13,
                                     color="#33485e", lw=1.2))

    nodes = [
        (3.5, 11.0, 3.0, 0.8, "samplesheet.csv\n(HiFi / ONT / Hi-C)", "#dfe7ef"),
        (3.5, 9.7, 3.0, 0.8, "1 · Read QC & profiling\nNanoPlot · seqkit · Meryl · GenomeScope2", "#cfe3d4"),
        (3.5, 8.4, 3.0, 0.8, "2 · Contamination screen\nKraken2 / FCS-GX (flag & remove)", "#cfe3d4"),
        (3.5, 7.1, 3.0, 0.8, "3 · Assembly\nhifiasm / Verkko / Flye", "#f6e0c4"),
        (3.5, 5.8, 3.0, 0.8, "4 · purge_dups\nremove false duplications", "#f6e0c4"),
        (3.5, 4.5, 3.0, 0.8, "5 · Scaffolding\nYaHS / SALSA (Hi-C / Omni-C)", "#f6e0c4"),
        (3.5, 3.2, 3.0, 0.8, "6 · Polishing (optional)", "#f6e0c4"),
        (3.5, 1.9, 3.0, 0.8, "7 · QC & benchmarking\nMerqury · BUSCO · QUAST · tidk · telomere/centromere table", "#cfe3d4"),
        (3.5, 0.5, 3.0, 0.8, "8 · Release\nFASTA · AGP · MultiQC · assembly_stats.json", "#dfe7ef"),
    ]
    for (x, y, w, h, t, c) in nodes:
        box(x, y, w, h, t, c)
    for i in range(len(nodes) - 1):
        x1 = nodes[i][0] + nodes[i][2] / 2
        y1 = nodes[i][1]
        x2 = nodes[i + 1][0] + nodes[i + 1][2] / 2
        y2 = nodes[i + 1][1] + nodes[i + 1][3]
        arrow(x1, y1, x2, y2)
    ax.text(5.0, 11.95, "t2t-flow — pipeline DAG", ha="center", fontsize=12, fontweight="bold", color="#13242f")
    _save(fig, "assembly_dag.png")


if __name__ == "__main__":
    genomescope_profile()
    merqury_spectra_good()
    merqury_spectra_bad()
    merqury_qv_concept()
    busco_good_vs_dup()
    tidk_telomere()
    purge_dups_cutoffs()
    assembly_dag()
    print("\nAll figures written to", OUT)
