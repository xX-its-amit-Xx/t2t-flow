# t2t-flow: Interpreting your assembly QC

This is the deep guide to reading `t2t-flow`'s QC and deciding **what to do next**. It expands the README's QC section with concrete thresholds, worked decision trees, and figure references. Read it alongside the actual files in `results/qc/`, `results/readqc/`, and `results/release/` (mapped in [`output.md`](output.md)).

**The T2T mental model:** a finished chromosome is *one* contiguous scaffold, *correctly* phased, *accurate* at the base level, *complete* in gene content, and *capped* by telomeres at both ends. The five QC families below each measure one of those properties:

| Property | Measured by | Good signal |
|----------|-------------|-------------|
| Contiguity | gfastats / QUAST N50 | Scaffold N50 ≈ chromosome size; #scaffolds ≈ chromosome count |
| Phasing / non-redundancy | Merqury spectra-cn, BUSCO Duplicated, GenomeScope size | No duplicated copy peak; D ≲ 2–3 %; size ≈ estimate |
| Base accuracy | Merqury QV | QV ≥ 40 (HiFi), ideally ≥ 50 |
| Completeness | BUSCO C, Merqury k-mer completeness | C ≥ 90 %; completeness ≥ 95 % |
| Chromosome integrity | TIDK telomere plot, telomere table | Telomeres at **both** ends |

---

## GenomeScope2 — set your expectations first {#genomescope2}

![GenomeScope2 profile](img/genomescope_profile.png)

*Caption: GenomeScope2 linear k-mer spectrum (coverage on x, distinct-k-mer count on y).* **Interpretation:** the homozygous peak position × k-mer coverage estimates **genome size**; a half-coverage heterozygous peak whose area relative to the homozygous peak gives **heterozygosity**; the right tail is **repeat content**. This estimate is your yardstick for everything downstream — the final assembly size should land near it.

**Read it like this:**
- Two clean peaks (het at ~½ of hom): diploid, heterozygosity = het/(het+hom) area ratio. Expect the assembler to over-produce haplotigs in proportion to heterozygosity → purge_dups will matter more.
- One peak only: near-homozygous or effectively haploid; purge_dups will do little.
- Unfittable spike near coverage 1, or model "fit" warning: **contamination or low-quality reads** — screen before trusting size/ploidy.

**Decision:** record the estimated genome size `G`. After assembly, if `assembly_size ≫ G` you have uncollapsed duplication; if `assembly_size ≪ G` you have under-assembly/low coverage.

---

## Merqury — base accuracy (QV) and non-redundancy {#merqury}

### The QV concept

![Merqury QV concept](img/merqury_qv_concept.png)

*Caption: Merqury derives QV from k-mers found only in the assembly (assumed errors) versus shared with the reads.* **Interpretation:** QV is Phred-scaled per-base accuracy:

| QV | Accuracy | Errors |
|----|----------|--------|
| 30 | 99.9 % | 1 / 1 kb |
| 40 | 99.99 % | 1 / 10 kb |
| 50 | 99.999 % | 1 / 100 kb |
| 60 | 99.9999 % | 1 / 1 Mb |

Target **QV ≥ 40** from HiFi; reference-grade is QV ≥ 50.

### The copy-number spectrum

![Merqury spectra-cn — good](img/merqury_spectra_cn_good.png)

*Caption: a GOOD spectra-cn.* **Interpretation:** read k-mers sit under the expected 1-copy (and 2-copy for diploid) curves; the **black read-only area is tiny** → high completeness; no extra duplicated peak.

![Merqury spectra-cn — bad](img/merqury_spectra_cn_bad.png)

*Caption: a BAD spectra-cn.* **Interpretation:** a **black read-only peak** at 1× coverage = real sequence missing from the assembly (incompleteness); a **duplicated 2-copy peak** where you expected 1-copy = haplotype retained twice (uncollapsed duplication → purge_dups).

### Decision tree — Merqury

```
Merqury QV?
├─ QV ≥ 40 and tiny read-only peak ........... base accuracy & completeness OK; move on to BUSCO/contiguity.
├─ QV 35–40 .................................. acceptable; if you need reference grade, --run_polishing.
└─ QV < 35
   ├─ large read-only (black) peak ........... missing sequence -> check coverage; re-screen contamination
   │                                            (a contaminant inflates "error" k-mers); re-assemble if low cov.
   └─ small read-only peak ................... true base errors -> --run_polishing; verify reads are HiFi not CLR;
                                                screen contamination (--kraken2_db / --run_fcs_gx).

Extra "2-copy / duplicated" peak present?
└─ yes ...................................... uncollapsed haplotypes -> see "Duplication" below (purge_dups).
```

**Worked example — "my Merqury QV is 28":** QV 28 ≈ 1 error / 600 bp, far below HiFi expectations. Step 1: confirm inputs are real HiFi (CLR/ONT-only consensus is naturally lower). Step 2: run the contamination screen — foreign sequence shows up as assembly-only k-mers and depresses QV. Step 3: enable `--run_polishing` (Racon) and re-measure. If QV is still low with clean HiFi, suspect a heterozygosity/phasing problem inflating error k-mers and revisit purge_dups/phasing.

---

## BUSCO — gene completeness and the duplication signal {#busco}

![BUSCO good vs duplicated](img/busco_good_vs_dup.png)

*Caption: BUSCO C/S/D/F/M bars — clean (left) vs high-Duplicated (right).* **Interpretation:** aim for **Complete ≥ 90 %**, **Single-copy** dominant, **Duplicated ≲ 2–3 %**. High **Duplicated** = the same genes assembled twice = uncollapsed haplotypes/over-assembly. High **Fragmented/Missing** with low Duplicated = incompleteness or a poorly matched lineage.

**Picking a lineage for a non-model organism:** choose the **closest `*_odb10` clade** you can (e.g. `insecta_odb10`, `vertebrata_odb10`, `embryophyta_odb10`). If nothing is close, use `--busco_lineage auto` and treat the score as **relative** (compare across your own runs), not as an absolute completeness claim.

### Decision tree — BUSCO {#duplication}

```
BUSCO Duplicated (D)?
├─ D ≤ 3% ................................... good; non-redundant. Check Complete next.
├─ D 3–10% ................................. mild over-assembly -> ensure purge_dups ran;
│                                            for hifiasm, use Hi-C phasing (--h1/--h2) to separate haplotypes.
└─ D > 10% ................................. strong uncollapsed-haplotype signal:
   1. Confirm assembly_size ≫ GenomeScope estimate (corroborates duplication).
   2. Make sure --skip_purgedups is NOT set; inspect purge_dups before/after gfastats.
   3. Re-check purge_dups cutoffs plot (below) — cutoffs may need manual tuning for high heterozygosity.
   4. Re-run; D should fall and assembly_size should approach the GenomeScope estimate.

BUSCO Complete (C)?
├─ C ≥ 90% ................................. good completeness.
└─ C < 90% with high Missing/Fragmented .... wrong/distant lineage? try --busco_lineage auto or a closer clade;
                                             if lineage is right, suspect low coverage / under-assembly.
```

**Worked example — "my BUSCO Duplication is 15 %":** this is the canonical uncollapsed-haplotype case. Cross-check: assembly total length is likely well above the GenomeScope2 estimate and the Merqury spectra-cn shows a duplicated 2-copy peak. Fix: ensure `purge_dups` is enabled, inspect its cutoffs plot (tune if heterozygosity is high), and for `hifiasm` provide Hi-C for haplotype phasing. After purging, Duplicated should drop into the low single digits and size should converge on `G`.

---

## Contiguity / N50 — and what scaffolding should buy you {#contiguity}

**Interpretation:** N50 = the length such that 50 % of the assembly sits in contigs/scaffolds at least that long.

| Stage | Typical contig N50 | Typical scaffold N50 |
|-------|--------------------|----------------------|
| HiFi-only | multi-Mb (often 1–20 Mb) | = contig N50 (no scaffolding) |
| HiFi + Hi-C (YAHS/SALSA) | unchanged | **chromosome scale** (tens of Mb → whole chromosomes) |
| Verkko (HiFi+ONT) | very high; often near-T2T per chromosome | chromosome scale |

```
After scaffolding, is scaffold N50 ≫ contig N50 and #scaffolds ≈ chromosome count?
├─ yes ..................................... chromosome-scale; good. Proceed to telomere check.
└─ no
   ├─ few/low-depth Hi-C ................... add Hi-C coverage.
   ├─ wrong enzyme (SALSA) ................. set --hic_enzyme correctly.
   └─ hic_1/hic_2 mis-paired ............... verify samplesheet pairing and read orientation.
```

---

## purge_dups cutoffs — make sure purging was sane {#purgedups-cutoffs}

![purge_dups cutoffs](img/purge_dups_cutoffs.png)

*Caption: purge_dups read-depth histogram with auto low/mid/high cutoffs.* **Interpretation:** a clean **bimodal** histogram (a ~½-depth haplotig mode and a full-depth primary mode) with the **mid cutoff in the valley** between them is ideal. A **unimodal** histogram means the genome is already haploid-collapsed (purging removes little — expected for low-heterozygosity samples). If auto cutoffs fall in the wrong valley (common at very high or very low coverage), override them via `calcuts` args and re-run before trusting the purged FASTA.

---

## TIDK — the telomere (T2T) signal {#telomeres}

![TIDK telomere plot](img/tidk_telomere.png)

*Caption: TIDK per-window telomere-motif counts along each scaffold.* **Interpretation:** dense motif clusters at **both ends** of a chromosome-scale scaffold = a capped, T2T chromosome. One-end peaks = single capped telomere (partial). Internal peaks = possible misjoin or interstitial telomeric repeat.

```
Is the telomere motif right?
├─ TIDK explore top motif ≈ --telomere_motif ... good; read the plot.
└─ mismatch ................................... set --telomere_motif to the explore result
                                                (vertebrates TTAGGG, many plants TTTAGGG, etc.) and re-run TIDK.

Per scaffold:
├─ telomeres both ends ........................ candidate complete (T2T) chromosome.
├─ one end ................................... partially capped; gap likely at the other end.
└─ internal peak ............................. inspect for misjoin in the AGP / break and re-scaffold.
```

---

## Per-chromosome telomere/centromere table {#telomere-table}

`telomere_table.py` writes `results/qc/<sample>.telomere_centromere.tsv` (+ `.json`) summarizing, per scaffold: length, telomere presence at 5′/3′ ends, and putative centromeric/satellite array positions. **Interpretation:** count scaffolds with telomeres at **both** ends and a single central repeat array — those are your candidate finished chromosomes. This table, plus the `assembly_stats.json` in `results/release/`, is the fastest way to report "X of N chromosomes are T2T."

---

## Putting it together — a release checklist

Before you call an assembly done, confirm all of:

- [ ] Assembly size within ~10 % of the GenomeScope2 estimate.
- [ ] Merqury **QV ≥ 40** and small read-only peak in spectra-cn.
- [ ] BUSCO **Complete ≥ 90 %**, **Duplicated ≲ 3 %**.
- [ ] Scaffold **N50 chromosome-scale**, #scaffolds near the chromosome count.
- [ ] No duplicated 2-copy peak in Merqury spectra-cn.
- [ ] Telomere table: telomeres at both ends of most chromosome-scale scaffolds.
- [ ] Contamination screen clean; FCS-GX (if run) reports no foreign sequence.

---

See also: [usage](usage.md) · [outputs](output.md) · [parameters](parameters.md) · [README](../README.md)
