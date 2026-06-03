# t2t-flow: Usage

This guide covers everything you need to run `t2t-flow` on real data: building the samplesheet, every parameter, profiles, running on HPC and the cloud, resuming, and troubleshooting common assembly problems.

- [1. Prerequisites](#1-prerequisites)
- [2. The samplesheet](#2-the-samplesheet)
- [3. Running the pipeline](#3-running-the-pipeline)
- [4. Parameters](#4-parameters)
- [5. Profiles](#5-profiles)
- [6. Running on HPC](#6-running-on-hpc)
- [7. Running on the cloud](#7-running-on-the-cloud)
- [8. Resuming](#8-resuming-resume)
- [9. Reference databases](#9-reference-databases)
- [10. Troubleshooting](#10-troubleshooting)

---

## 1. Prerequisites

| Requirement | Minimum | Notes |
|-------------|---------|-------|
| Nextflow | ≥ 24.04.0 | DSL2 + nf-schema 2.1.1 plugin. Requires Java 17+. |
| Container engine | Docker **or** Singularity/Apptainer **or** Conda | Every process is containerized; do not install tools on the host. |
| RAM | 256 GB+ for vertebrate genomes | `hifiasm`/`verkko` are the peak-RAM stages. |
| Disk | 5–20× the input read volume | Intermediate alignments and graphs are large. |

Install Nextflow:

```bash
curl -s https://get.nextflow.io | bash
sudo mv nextflow /usr/local/bin/   # optional
nextflow -version
```

---

## 2. The samplesheet

`--input` points to a CSV with this exact header:

```csv
sample,hifi,ont,hic_1,hic_2
```

One row per sample; put all read types for a sample on the same row.

| Column | Required | Accepted | Meaning |
|--------|----------|----------|---------|
| `sample` | **yes** | unique string, no whitespace | Becomes `meta.id` and the output prefix. |
| `hifi` | conditional | `.fastq.gz`/`.fq.gz` | PacBio HiFi reads. |
| `ont` | conditional | `.fastq.gz`/`.fq.gz` | Oxford Nanopore reads. |
| `hic_1` | optional | `.fastq.gz` | Hi-C R1. Needed for scaffolding / `hifiasm --h1`. |
| `hic_2` | optional | `.fastq.gz` | Hi-C R2. Must accompany `hic_1`. |

**Rules**

- Each sample needs **at least one** of `hifi` or `ont`.
- The pipeline picks the **primary long-read set** as `hifi` if present, otherwise `ont`. This drives profiling, purge_dups, and (optionally) polishing.
- Hi-C is only used if **both** `hic_1` and `hic_2` are present.
- Leave optional cells empty (trailing commas), e.g. `sampleA,a.hifi.fq.gz,,,`.
- Paths can be absolute, relative to the launch dir, or `s3://`/`gs://` URLs.

**Examples**

HiFi + Hi-C (recommended for chromosome-scale, `hifiasm`+`yahs`):
```csv
sample,hifi,ont,hic_1,hic_2
beetleX,/data/beetleX.hifi.fastq.gz,,/data/beetleX.hic.R1.fastq.gz,/data/beetleX.hic.R2.fastq.gz
```

HiFi + ONT (for `verkko`, or `hifiasm --ul`):
```csv
sample,hifi,ont,hic_1,hic_2
frogY,/data/frogY.hifi.fastq.gz,/data/frogY.ont.fastq.gz,,
```

ONT-only (use `--assembler flye --flye_mode --nano-hq`):
```csv
sample,hifi,ont,hic_1,hic_2
snailZ,,/data/snailZ.ont.fastq.gz,,
```

---

## 3. Running the pipeline

### Smoke test

```bash
nextflow run . -profile test -stub-run --outdir results
nextflow run . -profile test -stub-run --outdir results   # what CI runs
```

### Typical real run

```bash
nextflow run . \
    -profile docker \
    --input samplesheet.csv \
    --outdir results \
    --assembler hifiasm \
    --scaffolder yahs \
    --kmer_size 21 \
    --ploidy 2 \
    --busco_lineage vertebrata_odb10 \
    --telomere_motif AACCCT \
    -resume
```

It is best practice to capture all parameters in a `-params-file`:

```yaml
# params.yaml
input: samplesheet.csv
outdir: results
assembler: hifiasm
scaffolder: yahs
busco_lineage: insecta_odb10
kmer_size: 21
ploidy: 2
telomere_motif: AACCCT
kraken2_db: /db/kraken2/standard
```
```bash
nextflow run . -profile singularity -params-file params.yaml -resume
```

---

## 4. Parameters

A condensed reference; the full table with types/defaults is in [`parameters.md`](parameters.md).

### Choosing an assembler (`--assembler`)
- **`hifiasm`** (default): best for HiFi (± ONT ultra-long ± Hi-C phasing). Highest contiguity for most genomes.
- **`verkko`**: HiFi + ONT graph assembly; strongest at fully resolving repeats toward T2T, highest RAM.
- **`flye`**: works for HiFi or ONT alone; lower RAM, good fallback when HiFi is absent. Set `--flye_mode` (`--pacbio-hifi`, `--nano-hq`, `--nano-raw`).

### Choosing a scaffolder (`--scaffolder`)
- **`yahs`** (default): fast, robust Hi-C scaffolder; pairs with `chromap` alignments.
- **`salsa`**: alternative Hi-C scaffolder; uses `--hic_enzyme`.

### Stage toggles
| Flag | Effect |
|------|--------|
| `--skip_readqc` | Skip stage 1. **Note:** disables Merqury (no Meryl DB). |
| `--skip_contamination` | Skip Kraken2 read screening. |
| `--skip_purgedups` | Skip haplotype-duplicate purging. |
| `--skip_scaffolding` | Stop at contigs (no AGP / chromosome-scale). |
| `--skip_busco` | Skip BUSCO. |
| `--run_polishing` | Enable Racon polishing (off by default). |
| `--run_fcs_gx` | Enable NCBI FCS-GX assembly decontamination (needs DB + tax id). |

### Profiling / QC knobs
- `--kmer_size 21` — used consistently by Meryl, GenomeScope2, Merqury.
- `--ploidy 2`, `--genome_size 1.2g` (optional hint).
- `--busco_lineage auto|<clade>_odb10`, `--busco_mode genome`, `--busco_db /path` (offline).
- `--telomere_motif AACCCT` or `--tidk_clade <preset>`.

### Resource caps
- `--max_cpus 16`, `--max_memory '128.GB'`, `--max_time '240.h'` clamp every process. Raise these for large genomes.

---

## 5. Profiles

| Profile | Use | Combine with |
|---------|-----|--------------|
| `docker` | Local/cloud with Docker | `slurm`, `awsbatch` |
| `singularity` | HPC (rootless) | `slurm`, `lsf` |
| `conda` | No container engine available | any executor |
| `slurm` | SLURM scheduler | a container profile |
| `lsf` | LSF/`bsub` scheduler | a container profile |
| `awsbatch` | AWS Batch | `docker` |
| `test` | CI / smoke test | `docker` or `-stub-run` |

Always pair an executor profile with a container/conda profile, e.g. `-profile slurm,singularity`.

**Reproducibility & validation status.** The `docker` and `singularity` profiles are the recommended, fully reproducible paths and have both been validated end to end on real public HiFi data (identical results, e.g. Merqury QV 48.87). The `conda` profile works (every process declares a pinned `conda` spec) but is inherently less reproducible: each process builds its own environment from a fresh solve, so it needs **substantial disk** (BUSCO's dependency tree alone — augustus/blast/metaeuk/… — is several GB; the full set exceeds ~30 GB) and can occasionally need an extra version pin when bioconda dependencies drift. Prefer a container engine; reach for `conda` only when none is available, give it a large working disk, and consider `conda clean -a` between large runs.

---

## 6. Running on HPC

### SLURM

```bash
nextflow run . \
    -profile slurm,singularity \
    -params-file params.yaml \
    --max_cpus 48 --max_memory '500.GB' --max_time '240.h' \
    -resume
```

Best practices:
- Launch from a login node inside `tmux`/`screen`, or wrap the `nextflow run` itself in a small `sbatch` script so it survives disconnects.
- Point Nextflow's work directory and Singularity cache at fast, large scratch:
  ```bash
  export NXF_WORK=/scratch/$USER/t2t-work
  export NXF_SINGULARITY_CACHEDIR=/scratch/$USER/singularity_cache
  ```
- Pre-pull containers once on a node with internet, then run offline.
- Set per-queue settings (partition, account, QoS) via a custom config passed with `-c mycluster.config`.

### LSF

```bash
nextflow run . -profile lsf,singularity -params-file params.yaml -resume
```

---

## 7. Running on the cloud

### AWS Batch

```bash
nextflow run . \
    -profile awsbatch,docker \
    --input s3://my-bucket/samplesheet.csv \
    --outdir s3://my-bucket/results \
    -work-dir s3://my-bucket/work \
    -resume
```

Provide the AWS Batch queue and region in a config (`-c aws.config`). Use large-RAM compute environments for the assembly stage.

---

## 8. Resuming (`-resume`)

`t2t-flow` caches every process. Add `-resume` to continue from the last successful step after a crash or a parameter tweak:

```bash
nextflow run . -profile docker -params-file params.yaml -resume
```

- Resume reuses cached results for processes whose inputs/code are unchanged.
- Changing a parameter that feeds a process invalidates that process **and everything downstream**.
- Do **not** delete the `work/` directory if you intend to resume.
- Clean old runs with `nextflow clean -f -before <run_name>`.

---

## 9. Reference databases

| Feature | Param | Where to get it |
|---------|-------|-----------------|
| Read contamination | `--kraken2_db` | A Kraken2 DB (e.g. Standard, PlusPF). RAM ≈ DB size. |
| Assembly decontamination | `--fcs_gx_db` + `--fcs_gx_tax_id` | NCBI FCS-GX GX database (large; needs `--run_fcs_gx`). |
| Gene completeness | `--busco_db` | Pre-downloaded BUSCO lineage for offline `--busco_lineage`. |

Without `--kraken2_db`, the contamination stage is a pass-through. Without `--run_fcs_gx`, FCS-GX is skipped.

---

## 10. Troubleshooting

### Pipeline / config

| Symptom | Cause | Fix |
|---------|-------|-----|
| `Cannot find samplesheet` / schema error | Wrong header or path | Use the exact header; check absolute paths; keep trailing commas for empty cells. |
| Process killed (OOM / 137) | Memory cap too low | Raise `--max_memory`; assembly needs 256 GB+ for vertebrates. |
| Walltime exceeded | `--max_time` too low for the queue | Raise `--max_time` and the SLURM/LSF partition limit. |
| Containers fail to pull | No internet on compute nodes | Pre-pull and set `NXF_SINGULARITY_CACHEDIR`. |
| `-resume` re-runs everything | `work/` deleted or a param changed | Keep `work/`; only change params you intend to. |

### Assembly quality (see [`interpretation.md`](interpretation.md) for full decision trees)

| Symptom | Likely cause | Action |
|---------|--------------|--------|
| High BUSCO **Duplicated** (>5 %), inflated assembly size vs GenomeScope estimate | Uncollapsed haplotypes | Ensure purge_dups is on (`--skip_purgedups` not set); consider `hifiasm` Hi-C phasing. |
| Many small contigs, low N50 | Low coverage or wrong read type | Check coverage in GenomeScope2; verify HiFi vs ONT and `--flye_mode`. |
| Merqury **QV < 35** | Residual base errors or contamination | Enable `--run_polishing`; screen with Kraken2/FCS-GX. |
| GenomeScope2 will not fit / huge low-coverage spike | Contamination or adapter/quality issues | Run contamination screen; verify input is true HiFi/clean ONT. |
| Scaffold N50 ≈ contig N50 after YAHS | Weak/ misconfigured Hi-C | Check Hi-C depth; set correct `--hic_enzyme` (SALSA2); verify pairing of `hic_1`/`hic_2`. |
| No telomeres in TIDK plot | Wrong motif | Set `--telomere_motif` for your clade (e.g. `TTAGGG` for vertebrates, `TTTAGGG` for many plants). |
| BUSCO mostly Missing/Fragmented | Distant or wrong lineage | Try `--busco_lineage auto` or a closer `*_odb10`; interpret as relative completeness. |

### Getting help

- Inspect failed tasks under `work/<hash>/` (`.command.sh`, `.command.log`, `.command.err`).
- Re-run a single sample with a one-row samplesheet to iterate quickly.
- Read [`output.md`](output.md) to map each result file, and [`interpretation.md`](interpretation.md) to decide next steps.

---

See also: [outputs](output.md) · [interpretation](interpretation.md) · [parameters](parameters.md) · [README](../README.md)
