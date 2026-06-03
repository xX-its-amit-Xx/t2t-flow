# t2t-flow: Outputs

This document describes every directory and file `t2t-flow` writes under `--outdir`. Files are published according to `--publish_dir_mode` (default `copy`). `<sample>` is the `sample` column of your samplesheet (`meta.id`).

## Directory overview

```
results/
├── readqc/
├── contamination/
├── assembly/
├── purge_dups/
├── scaffolding/
├── polishing/
├── qc/
├── release/
├── multiqc/
└── pipeline_info/
```

Stages you skip (`--skip_*`) or do not enable (`--run_*`) simply omit their directory.

---

## 1. `readqc/` — read QC & genome profiling

Produced by the `READ_QC` subworkflow (stage 1).

| File | Tool | Meaning |
|------|------|---------|
| `<sample>.seqkit-stats.tsv` | seqkit | Per-read-set stats: #seqs, total bp, N50, min/max/mean length, GC. |
| `<sample>*NanoPlot*.html` / `*.png` | NanoPlot | Read-length and quality distributions (interactive + figures). |
| `<sample>*NanoStats.txt` | NanoPlot | Tabular read-quality summary (mean/median length & Q). |
| `<sample>.meryldb/` | Meryl | k-mer count database (directory). Reused later by Merqury. |
| `<sample>*.hist` | Meryl | k-mer frequency histogram feeding GenomeScope2. |
| `<sample>_summary.txt` | GenomeScope2 | **Estimated genome size, heterozygosity, repeat %, ploidy fit.** |
| `<sample>_model.txt` | GenomeScope2 | Fitted model parameters. |
| `<sample>*.png` | GenomeScope2 | Linear/log k-mer spectrum plots. |

**What to look at first:** `<sample>_summary.txt` (genome size, heterozygosity) and the GenomeScope2 plot — these set expectations for assembly size and duplication. See [interpretation §GenomeScope2](interpretation.md#genomescope2).

---

## 2. `contamination/` — read & assembly decontamination

Produced by `CONTAMINATION_SCREEN` (and FCS-GX if `--run_fcs_gx`). Only populated when `--kraken2_db` (and/or FCS-GX inputs) are provided.

| File | Tool | Meaning |
|------|------|---------|
| `<sample>.kraken2.report.txt` | Kraken2 | Taxonomic composition of the reads. |
| `<sample>.kraken2.classifiedreads.txt` | Kraken2 | Per-read taxonomic assignments. |
| `<sample>*.classified.fastq.gz` / `*.unclassified.fastq.gz` | Kraken2 | Reads split by classification. |
| `<sample>*.fastq.gz` (extracted) | KrakenTools | **Cleaned reads** with `--contaminant_taxids` removed; fed to assembly. |
| `<sample>.fcs_gx_report.txt` | FCS-GX | Contaminant contig/region calls on the assembly. |
| `<sample>.taxonomy.rpt` | FCS-GX | Per-sequence taxonomy report. |
| `<sample>.clean.fasta` / `<sample>.contam.fasta` | FCS-GX | Decontaminated vs flagged sequences. |

**Use:** confirm the Kraken2 report is dominated by your target taxon; the extracted FASTQ is what actually enters assembly.

---

## 3. `assembly/` — primary assembly

Produced by the `ASSEMBLY` subworkflow (one of hifiasm/verkko/flye).

| File | Tool | Meaning |
|------|------|---------|
| `<sample>*.p_ctg.fasta` | hifiasm | **Primary contig assembly** (main output). |
| `<sample>*.hap1.p_ctg.fasta` / `*.hap2.p_ctg.fasta` | hifiasm | Phased haplotype assemblies (with Hi-C/trio). |
| `<sample>*.p_ctg.gfa`, `*.hap1.p_ctg.gfa`, `*.hap2.p_ctg.gfa` | hifiasm | Assembly graphs. |
| `<sample>*.assembly.fasta` | verkko | Verkko consensus assembly. |
| `<sample>*.gfa` | verkko | Verkko assembly graph. |
| `<sample>*.assembly.fasta` | flye | Flye assembly. |
| `<sample>*.assembly_graph.gfa` / `*.gv` | flye | Flye graph. |
| `<sample>*.assembly_info.txt` | flye | Per-contig length, coverage, circularity. |
| `<sample>*.gfastats.txt` | gfastats | Contiguity stats (N50, L50, #contigs, total bp). |
| `*.log` | assembler | Run log. |

**What to look at first:** the primary FASTA and its `gfastats.txt` N50; compare total length against the GenomeScope2 estimate — large excess hints at uncollapsed haplotypes (→ purge_dups).

---

## 4. `purge_dups/` — haplotype-duplicate purging

Produced by `PURGE_DUPS` (skipped if `--skip_purgedups`).

| File | Tool | Meaning |
|------|------|---------|
| `<sample>*.purged.fa` | purge_dups | **Primary assembly with duplicate haplotigs removed.** |
| `<sample>*.hap.fa` | purge_dups | Removed haplotigs (the alternate copies). |
| `<sample>*.cutoffs` | calcuts | Chosen depth cutoffs (low/mid/high). |
| `PB.stat`, `PB.base.cov` | pbcstat | Per-base read-depth stats from the read→assembly alignment. |
| `<sample>*.dups.bed` | purge_dups | Regions flagged as duplicates. |
| `<sample>*.before.gfastats.txt` / `*.after.gfastats.txt` | gfastats | Contiguity before vs after purging. |

**Use:** compare before/after gfastats — total length and contig count should drop toward the GenomeScope2 estimate while N50 stays similar or improves. See [interpretation §Duplication](interpretation.md#duplication).

---

## 5. `scaffolding/` — Hi-C scaffolding

Produced by `SCAFFOLDING` (skipped if `--skip_scaffolding`).

| File | Tool | Meaning |
|------|------|---------|
| `<sample>*_scaffolds_final.fa` | YAHS | **Chromosome-scale scaffolds (FASTA).** |
| `<sample>*_scaffolds_final.agp` | YAHS | AGP describing how contigs were joined into scaffolds. |
| `<sample>*scaffolds_FINAL.fasta` / `*.agp` | SALSA2 | Scaffolds + AGP (if `--scaffolder salsa`). |
| `<sample>*.bam` / `*.sam` | chromap + samtools | Hi-C alignments used for scaffolding. |
| `<sample>*.fai` | samtools faidx | FASTA index of the input assembly. |

**Use:** scaffold N50 (in `qc/`) should jump to chromosome scale and #scaffolds approach the haploid chromosome count. The AGP is required for submission to public archives.

---

## 6. `polishing/` — optional long-read polishing

Produced by `POLISHING` only when `--run_polishing` is set.

| File | Tool | Meaning |
|------|------|---------|
| `<sample>*.racon.fasta` | Racon | Polished assembly (improves consensus QV). |

**Use:** re-check Merqury QV after polishing; expect QV to rise if base errors were the limiting factor.

---

## 7. `qc/` — QC & benchmarking

Produced by `QC_BENCHMARK`. This is the heart of assembly evaluation.

| File | Tool | Meaning |
|------|------|---------|
| `<sample>*.gfastats.txt` | gfastats | Final contiguity (N50, L50, #scaffolds, total bp, GC). |
| `<sample>*report.tsv` / `*report.html` | QUAST | Contiguity report (N50, NG50, #contigs, longest). |
| `<sample>*short_summary*.txt` / `*.json` | BUSCO | **Gene completeness:** C / S / D / F / M percentages. |
| `<sample>*full_table*` | BUSCO | Per-gene BUSCO status. |
| `<sample>*.qv` | Merqury | **Consensus quality value (QV)** — per-base accuracy (Phred). |
| `<sample>*.completeness.stats` | Merqury | k-mer completeness (% of read k-mers present in assembly). |
| `<sample>*.spectra-cn.*.png` | Merqury | **Copy-number spectrum** (read-only peak / duplication diagnostics). |
| `<sample>*.spectra-asm.*.png` | Merqury | Assembly k-mer spectrum. |
| `<sample>*.explore.tsv` | TIDK | Candidate telomere repeat motifs. |
| `<sample>*.tidk.search.tsv` | TIDK | Per-window counts of `--telomere_motif`. |
| `<sample>*.tidk.plot.svg` | TIDK | **Telomere distribution plot** along scaffolds. |
| `<sample>*.telomere_centromere.tsv` / `.json` | telomere_table.py | **Per-scaffold telomere (both-end) & centromere summary.** |

**What to look at first:** BUSCO C/D, Merqury QV + spectra-cn, scaffold N50, and the telomere table — together they tell you how close to T2T you are. See [interpretation.md](interpretation.md).

---

## 8. `release/` — final deliverables

Produced by the `RELEASE` subworkflow.

| File | Tool | Meaning |
|------|------|---------|
| `<sample>*.fasta` | pipeline | **Final assembly FASTA** (scaffolded/polished as configured). |
| `<sample>*.agp` | pipeline | Final AGP (empty/trivial if `--skip_scaffolding`). |
| `<sample>*.assembly_stats.json` | assembly_stats.py | **Machine-readable summary** combining gfastats + BUSCO + QV + telomere counts. |

**Use:** `assembly_stats.json` is the single artifact to track across runs and to attach to submissions/dashboards.

---

## 9. `multiqc/` — aggregated report

| File | Meaning |
|------|---------|
| `multiqc_report.html` | **One-page interactive report** aggregating seqkit, NanoPlot, QUAST, BUSCO, Kraken2, etc. across all samples. |
| `multiqc_data/` | Parsed data tables behind the report. |
| `multiqc_plots/` | Static plot exports. |

**Use:** open `multiqc_report.html` first to compare samples at a glance.

---

## 10. `pipeline_info/` — provenance

| File | Meaning |
|------|---------|
| `software_versions.yml` | Exact version of every tool used (one entry per process). |
| `execution_report*.html` | Per-task CPU/RAM/time usage. |
| `execution_timeline*.html` | Gantt timeline of the run. |
| `execution_trace*.txt` | Machine-readable task trace. |
| `pipeline_dag*.html` | Rendered DAG of the executed workflow. |

**Use:** cite tool versions from `software_versions.yml`; use the execution report to right-size `--max_cpus`/`--max_memory` for future runs.

---

See also: [usage](usage.md) · [interpretation](interpretation.md) · [parameters](parameters.md) · [README](../README.md)
