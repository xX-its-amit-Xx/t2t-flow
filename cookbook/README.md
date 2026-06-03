# t2t-flow Cookbook

Fully-worked, end-to-end examples of running **t2t-flow** on **real, public datasets**.
Each recipe is a self-contained folder with a `samplesheet.csv`, a copy-pasteable
`commands.sh`, and a narrated curation walk-through that mirrors the decisions a real
genome-assembly curator makes while staring at the QC outputs.

> **About the figures.** The QC plots referenced from these recipes live in
> `../docs/img/` and are **representative / schematic**. They illustrate what a
> *good* (or a *bad*) profile looks like so you can calibrate your eye; they were
> **not** all regenerated from a full production run of every dataset below
> (assembling a 1 Gb vertebrate from raw reads is a multi-hundred-CPU-hour job).
> Where a figure is schematic this is stated at the point of use. Every **dataset,
> accession, and command**, by contrast, is real and was verified against the
> public archive at the time of writing (see the provenance notes in each recipe).

---

## The recipes

| # | Recipe | Organism | Data | What it teaches |
|---|--------|----------|------|-----------------|
| [01](01_heterozygous_eukaryote/README.md) | Heterozygous eukaryote | Banana weevil (*Cosmopolites sordidus*) | HiFi only | GenomeScope heterozygosity, hifiasm, purge_dups before/after |
| [02](02_hic_scaffolding/README.md) | Hi-C scaffolding | Zebra finch (*Taeniopygia guttata*) | HiFi + Arima Hi-C | YaHS scaffolding, contact maps, telomere/centromere table |
| [03](03_downstream_integration/README.md) | Downstream integration | (recipe 02 output) | scaffolds + tracks | JBrowse2 visualisation, hand-off to nf-core/genomeannotator |

---

## Dataset table (with verified sources)

| Recipe | Accession(s) | Platform | Archive | Verified URL | Status |
|--------|--------------|----------|---------|--------------|--------|
| 01 | `SRR18555109` (BioProject `PRJNA817621`) | PacBio Sequel II HiFi, ~25.8 Gbp, 1.71 M reads | NCBI SRA / ENA | <https://www.ebi.ac.uk/ena/browser/view/SRR18555109> | **Verified public** |
| 02 (HiFi) | GenomeArk `bTaeGut2` `*.hifi_reads.fastq.gz` | PacBio HiFi | GenomeArk S3 (`s3://genomeark`) | <https://www.genomeark.org/vgp-all/Taeniopygia_guttata.html> | **Verified public** |
| 02 (Hi-C) | GenomeArk `bTaeGut2` Arima `*_R1/R2.fq.gz` | Arima Hi-C, Illumina PE | GenomeArk S3 (`s3://genomeark`) | same species page | **Verified public** |

Provenance details (exact S3 keys / SRA filenames) are inside each recipe's README.

### Optional / alternative datasets referenced

These are mentioned in the walk-throughs as alternatives and are also real public data:

* **Baker's yeast Hi-C** `SRR7126301` — used by the Galaxy VGP training; a small,
  fast Hi-C set if you want a toy scaffolding run.
  <https://www.ebi.ac.uk/ena/browser/view/SRR7126301>
* **Wax apple** (*Syzygium samarangense*, autotetraploid) BioProject `PRJNA928838` —
  cited as a higher-ploidy contrast in recipe 01.

---

## Expected runtime and hardware

These are order-of-magnitude figures on a single fat node (the pipeline of course
scales out on a scheduler via `-profile slurm` etc.). HiFi download dominates wall
time for the larger recipes.

| Recipe | Genome size | Peak RAM | CPUs used | Wall time (download + compute) | Disk |
|--------|-------------|----------|-----------|--------------------------------|------|
| 01 banana weevil | ~0.6 Gbp | ~64 GB (hifiasm) | 16–32 | download ~1 h on 1 Gbit/s; compute ~6–10 h | ~150 GB |
| 02 zebra finch | ~1.0 Gbp | ~120 GB (hifiasm) | 32–48 | download ~3–5 h; compute ~12–24 h | ~500 GB |
| 03 integration | n/a (post-assembly) | <8 GB | 1–4 | minutes | <10 GB |

`-profile test -stub-run` completes either recipe's DAG in **seconds** with no
containers and no real data — that is what CI exercises. Use stub-run first to
confirm your environment and samplesheet parse before committing real compute.

---

## How to use a recipe

```bash
# 1. pick a recipe
cd cookbook/01_heterozygous_eukaryote

# 2. (optional) dry-run the DAG with no data / no containers
nextflow run ../.. -profile test -stub-run

# 3. fetch the data (each recipe's commands.sh does this for you)
bash commands.sh download

# 4. run for real
bash commands.sh run
```

Every command block in every recipe is copy-pasteable. Paths in the sample sheets are
written relative to the recipe folder; `commands.sh` `cd`s there first.

---

## Reading the QC figures (quick legend)

| Figure | Lives at | Good sign | Bad sign |
|--------|----------|-----------|----------|
| GenomeScope profile | `../docs/img/genomescope_profile.png` | clean het+hom peaks, model fit | smeared peaks, runaway error tail |
| Merqury spectra-cn | `../docs/img/merqury_spectra_cn_good.png` | one clean copy-number peak, little black (read-only) k-mers | large 2-copy peak (retained haplotigs), tall black bar (missing) |
| BUSCO good vs duplicated | `../docs/img/busco_good_vs_dup.png` | high single-copy, low duplicated | high **D**uplicated (false dups / unpurged haplotigs) |
| purge_dups cut-offs | `../docs/img/purge_dups_cutoffs.png` | low/mid/high cut-offs bracket the diploid peak sensibly | high cut-off clipping into the haploid peak |
| tidk telomere | `../docs/img/tidk_telomere.png` | repeat density spikes at both ends of each scaffold | interior spikes (mis-joins) or absent ends |

---

## Licence

t2t-flow is released under the **GPLv3**. The example datasets are governed by the
data-use policies of their respective archives (GenomeArk / VGP data are released
under the [Tobias terms / VGP data-use policy](https://genomeark.github.io/); SRA
data follow NCBI's open-access terms). Cite the original data generators if you
publish anything derived from these reads.
