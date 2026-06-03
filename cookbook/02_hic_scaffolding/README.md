# Recipe 02 — Hi-C scaffolding (HiFi → assembly → purge_dups → YaHS)

**Goal.** Start from PacBio HiFi **and** Arima Hi-C for a real VGP vertebrate, run the
full t2t-flow path (contigs → purge → **Hi-C scaffolding with YaHS**), and learn to
**judge chromosome-scale scaffolding**: reading scaffold N50 against the expected
karyotype, eyeballing the Hi-C contact map, and **confirming telomeres at scaffold ends
with `tidk`** plus the per-chromosome telomere/centromere table.

---

## 1. Dataset and provenance

| | |
|---|---|
| **Organism** | *Taeniopygia guttata* — zebra finch (VGP reference species) |
| **ToLID / GenomeArk** | `bTaeGut2` |
| **Genome size** | ~1.0 Gbp; expected karyotype ~40 chromosomes (incl. micro-chromosomes + Z/W) |
| **HiFi** | PacBio HiFi, 5 movies (`*.hifi_reads.fastq.gz`) |
| **Hi-C** | **Arima** Hi-C, Illumina PE, 9 lanes (`*_R1/_R2.fq.gz`) |
| **Bucket** | `s3://genomeark` (public, `--no-sign-request`) / HTTPS mirror `https://genomeark.s3.amazonaws.com` |
| **Verified source** | <https://www.genomeark.org/vgp-all/Taeniopygia_guttata.html> |

### Verified exact keys

> These S3 keys were listed and confirmed at the time of writing.

**HiFi** — `…/bTaeGut2/genomic_data/pacbio_hifi/`
```
m54306U_210519_154448.hifi_reads.fastq.gz
m54306U_210521_004211.hifi_reads.fastq.gz
m54306Ue_210629_211205.hifi_reads.fastq.gz
m54306Ue_210719_083927.hifi_reads.fastq.gz
m64055e_210624_223222.hifi_reads.fastq.gz
```

**Arima Hi-C** — `…/bTaeGut2/genomic_data/arima/` (paired `_R1`/`_R2`)
```
bTaeGut2_ARI8_001_USPD16084394-AK5146_HJFMFCCXY_L1..L8_{R1,R2}.fq.gz
bTaeGut2_ARI8_001_USPD16084394-AK5146_HJFMMCCXY_L6_{R1,R2}.fq.gz
```

`commands.sh download` fetches and concatenates these into three files the sample sheet
points at: `bTaeGut2.hifi.fastq.gz`, `bTaeGut2.hic_R1.fastq.gz`,
`bTaeGut2.hic_R2.fastq.gz`. (gzip streams concatenate losslessly, so `cat a.gz b.gz`
is a valid combined `.gz`.)

> **Heads-up on scale.** This is ~1 Gbp with deep Hi-C — a real multi-hundred-GB
> download and a many-hour assembly. To rehearse the *mechanics* of scaffolding cheaply,
> swap in the Galaxy VGP yeast Hi-C set (`SRR7126301`,
> <https://www.ebi.ac.uk/ena/browser/view/SRR7126301>) against a yeast HiFi assembly —
> same pipeline, minutes not hours.

---

## 2. The sample sheet

`samplesheet.csv` — HiFi plus a Hi-C pair, with the Arima enzyme declared:

```csv
sample,hifi,ont,hic_1,hic_2
bTaeGut2,data/bTaeGut2.hifi.fastq.gz,,data/bTaeGut2.hic_R1.fastq.gz,data/bTaeGut2.hic_R2.fastq.gz,Arima
```

`INPUT_CHECK` emits a `ch_hifi` tuple and — because both `hic_1` and `hic_2` are
present — a `ch_hic` tuple `( [id:bTaeGut2], [R1, R2] )`. That non-empty `ch_hic` is
what switches the `SCAFFOLDING` subworkflow on.

---

## 3. The exact commands

See `commands.sh`. The real run:

```bash
# 0. validate the DAG (no data, no containers)
nextflow run ../.. -profile test,docker -stub-run

# 1. fetch + concatenate the verified GenomeArk HiFi and Arima Hi-C
bash commands.sh download          # or: bash commands.sh download-aws  (needs awscli)

# 2. full run: contigs -> purge_dups -> YaHS scaffolding -> QC
nextflow run ../.. \
  -profile docker \
  --input samplesheet.csv \
  --outdir results \
  --assembler hifiasm \
  --scaffolder yahs \
  --kmer_size 21 \
  --ploidy 2 \
  --busco_lineage aves_odb10 \
  --busco_mode genome \
  --telomere_motif AACCCT \
  --hic_enzyme Arima \
  -resume
```

Flag reasoning:

* `--scaffolder yahs` — YaHS is the current default-best Hi-C scaffolder (fast, robust, AGP + scaffolds out). `--scaffolder salsa` is available as the alternative (`SALSA2`, needs a Hi-C BED and the enzyme).
* `--busco_lineage aves_odb10` — birds. Use the right lineage so the completeness/duplication numbers are biologically meaningful.
* `--telomere_motif AACCCT` — the **vertebrate telomere repeat** (the canonical TTAGGG / its complement AATCCC; `AACCCT` is the rotation `tidk` searches). This is correct for the zebra finch and is the t2t-flow default. (Plants would use `AAACCCT`/`TTTAGGG`; insects often `TTAGG`.)
* `--hic_enzyme Arima` — matches the Arima library; SALSA2 uses this to model restriction sites. (Arima's standard two-enzyme kit; YaHS does not strictly require it but it is recorded for provenance and for the SALSA path.)

Inside `SCAFFOLDING`: `SAMTOOLS_FAIDX` indexes the purged contigs, `CHROMAP_INDEX`
builds the chromap index, `CHROMAP` maps the Hi-C pairs (emitting SAM), a `SAMTOOLS`
sort/convert produces the sorted alignments, and `YAHS` consumes `(assembly, fai,
hic_alignments)` to emit `*_scaffolds_final.fa` + `*_scaffolds_final.agp`.

---

## 4. Curation: judging chromosome-scale scaffolding

### 4a. Scaffold N50 against the karyotype

After `YAHS`, `QC_BENCHMARK` reruns `GFASTATS` + `QUAST` on the scaffolds. The single
most important number is **scaffold N50** and the **count of large scaffolds**.

What a curator checks:

* **N50 should jump from contig-scale to chromosome-scale.** Pre-scaffolding contig N50
  for a good HiFi bird is typically a few–tens of Mb; after Hi-C it should rise to **tens
  of Mb**, with the largest scaffolds approaching whole macro-chromosomes (the zebra
  finch chr1 is ~120 Mb).
* **Number of large scaffolds ≈ haploid chromosome number.** The zebra finch has ~40
  chromosomes (many tiny micro-chromosomes + Z/W). You expect roughly that many
  multi-Mb scaffolds, *plus* a long tail of small unplaced bits. If you see **far more**
  big scaffolds than chromosomes, Hi-C under-joined (too little signal / bad mapping);
  **far fewer / suspicious mega-scaffolds** can mean **false joins** fusing distinct
  chromosomes — check the contact map (4b).
* **Total size should still match GenomeScope** (~1 Gbp). Scaffolding moves sequence
  around and adds gap `N`s; it must **not** materially change total length. A big size
  change means duplication was reintroduced or sequence was lost.

`QUAST` (`results/qc_benchmark/quast/report.tsv`) gives N50/L50/largest-scaffold; read
them next to the expected karyotype, not in the abstract.

### 4b. Reading the Hi-C contact map (qualitatively)

YaHS produces inputs you can render into a contact map (e.g. with `juicer pre` +
Juicebox, or `cooler`/HiGlass). t2t-flow's scaffolding stage exposes the alignments
needed; generating the `.hic`/`.cool` itself is an optional downstream step. **What you
are looking for, by eye:**

* **A strong diagonal** within each scaffold — contact frequency falls off smoothly with
  genomic distance. That is the hallmark of a correctly ordered/oriented scaffold.
* **Clean block structure**: each chromosome is a square block on the diagonal with
  little off-diagonal signal to *other* blocks. Bright **off-diagonal** patches mean two
  pieces that "want" to be adjacent were **not** joined (under-scaffolding) or were put
  in the wrong place.
* **Mis-joins** read as a **sharp break / discontinuity in the diagonal** within a
  single scaffold, or a bright **anti-diagonal** stripe (an inverted segment). Either is
  a cue to break the join (manual curation in Juicebox/PretextView) and re-run, or to
  re-examine YaHS parameters.
* **The "checkerboard" of micro-chromosomes** in birds is normal — many tiny strong
  blocks; do not mistake them for noise.

> The contact map is a **qualitative** instrument. You are not measuring a number; you
> are asking "does the diagonal hold and are the blocks clean?". Disagreements between
> the map and the N50 story (e.g. great N50 but ugly off-diagonal signal) are exactly
> where manual curation pays off.

### 4c. Telomeres at scaffold ends — `tidk`

A *truly* chromosome-scale scaffold should carry the **telomeric repeat at both ends**.
`QC_BENCHMARK` runs `TIDK_EXPLORE` → `TIDK_SEARCH` (`--telomere_motif AACCCT`) →
`TIDK_PLOT`, and `TELOMERE_TABLE` summarises per scaffold.

![tidk telomere density](../../docs/img/tidk_telomere.png)

*Figure: tidk telomere-repeat density along scaffolds (schematic). Spikes at the left
and right extremities are telomeres; a clean two-ended scaffold is "T2T-ish" for that
chromosome.*

How to read it:

* **Spikes at the extreme 5′ and 3′ ends** of a scaffold = telomere present. A scaffold
  with telomeres at **both** ends is a candidate **telomere-to-telomere** chromosome —
  the whole point of this pipeline.
* **A spike in the *interior*** of a scaffold is a **red flag**: it usually means a
  **mis-join** stitched two chromosome ends together internally. Cross-check against the
  Hi-C diagonal break at the same coordinate.
* **Absent telomeres** at an end just means that end is not yet complete (common; gap or
  rDNA/centromere-adjacent dropout) — not an error, but a to-do for finishing.
* `TIDK_EXPLORE` first *discovers* the dominant repeat empirically — confirm it reports
  the expected `AACCCT`/`TTAGGG` family for a vertebrate before trusting the search. If
  explore finds something else, your `--telomere_motif` is wrong for this organism.

### 4d. The per-chromosome telomere/centromere table

`TELOMERE_TABLE` (the custom `telomere_table.py`, fed `tidk` search + `samtools faidx`
`.fai` + the YaHS `.agp`) writes
`results/qc_benchmark/.../bTaeGut2.telomere_centromere.tsv` and `.json`. It is your
**finishing scorecard**, one row per scaffold:

| Column (conceptual) | What it tells you |
|---|---|
| scaffold / length | size vs expected chromosome |
| telomere_5prime / telomere_3prime | present? (from tidk density at the ends) |
| both_ends_telomere | the T2T flag — your count of two-ended chromosomes |
| telomere_repeat_count | depth of the terminal array |
| centromere_signal / position | from the AGP + repeat density valley (centromeres show up as a satellite/repeat-rich, often coverage-distinct band) |

**Curation use:** sort by `both_ends_telomere` to count how many chromosomes are
already gapless end-to-end, then triage the rest. Macro-chromosomes that are large but
**single-ended** are the highest-value finishing targets (often one telomere or the rDNA
array is missing). The table is also exactly what `RELEASE`/`ASSEMBLY_STATS_JSON` rolls
into the machine-readable `*.assembly_stats.json` for the record.

> **Centromere caveat.** Centromere *identification* from short-ish signal is
> approximate — the table flags **candidate** centromeric satellite bands, not validated
> centromeres. Treat it as a guide for where to point CENP-A ChIP or methylation data,
> not as ground truth.

---

## 5. What you get

```
results/
├── assembly/hifiasm/                      # primary contigs (+ hap1/2)
├── purge_dups/*.purged.fa                 # curated contigs feeding scaffolding
├── scaffolding/yahs/
│   ├── bTaeGut2_scaffolds_final.fa        # <- chromosome-scale scaffolds
│   └── bTaeGut2_scaffolds_final.agp       # contig->scaffold map (gaps, orientations)
├── qc_benchmark/
│   ├── quast/report.tsv                   # scaffold N50/L50/largest
│   ├── busco/ *short_summary*.txt         # aves_odb10 C/S/D/F/M
│   ├── merqury/ *.qv                       # reference-free QV
│   └── tidk/
│       ├── *.tidk.search.tsv , *.tidk.plot.svg
│       └── bTaeGut2.telomere_centromere.tsv / .json   # the finishing scorecard
├── multiqc/multiqc_report.html
└── pipeline_info/
```

The publishable assembly is `scaffolding/yahs/bTaeGut2_scaffolds_final.fa` with its
`.agp`. Feed both into [recipe 03](../03_downstream_integration/README.md) for
visualisation and annotation.

---

## 6. Curation checklist

1. **Scaffold N50** jumps to chromosome scale; **#large scaffolds ≈ karyotype**; total size unchanged (~1 Gbp).
2. **Contact map**: strong diagonal, clean per-chromosome blocks, no interior breaks / anti-diagonals.
3. **tidk explore** confirms the vertebrate `AACCCT`/`TTAGGG` repeat is the dominant one.
4. **tidk search/plot**: telomere spikes at scaffold **ends**; interior spikes ⇒ investigate mis-join.
5. **Telomere/centromere table**: count `both_ends_telomere` (your T2T tally); triage single-ended macro-chromosomes for finishing.
6. **BUSCO/Merqury**: scaffolding must not drop completeness or QV (it only reorders).
7. Disagreement between map and N50 ⇒ manual curation (Juicebox/PretextView), break the false join, `-resume`.
