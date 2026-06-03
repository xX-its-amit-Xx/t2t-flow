# t2t-flow: Parameter reference

Auto-doc-style reference for every `t2t-flow` parameter. Parameters are grouped by function. Types and defaults match `nextflow_schema.json`. Booleans are CLI flags (`--run_polishing` sets it to `true`). Set any parameter on the command line (`--param value`) or in a `-params-file` YAML/JSON.

> Note on resource caps: `--max_cpus`, `--max_memory`, `--max_time` clamp **per-process** requests; they do not set totals. Memory/time use Nextflow units (`'128.GB'`, `'240.h'`).

---

## Input / output

| Parameter | Type | Default | Required | Description |
|-----------|------|---------|----------|-------------|
| `input` | `string` (path) | `null` | **yes** | Path to the samplesheet CSV. Columns: `sample,hifi,ont,hic_1,hic_2`. Validated against `assets/samplesheet_schema.json`. |
| `outdir` | `string` (path) | `null` | **yes** | Output directory for all published results. |
| `email` | `string` | `null` | no | Email address for the completion summary. |
| `multiqc_title` | `string` | `null` | no | Custom title for the MultiQC report. |
| `multiqc_config` | `string` (path) | `null` | no | Additional MultiQC YAML config to merge. |

---

## Genome profiling

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `kmer_size` | `integer` | `21` | k-mer length used consistently by Meryl, GenomeScope2, and Merqury. 21 is standard for most genomes. |
| `ploidy` | `integer` | `2` | Expected ploidy passed to GenomeScope2. |
| `genome_size` | `string` | `null` | Optional known/estimated genome size (e.g. `1.2g`, `300m`). Hints gfastats NG50 and some assemblers. |
| `skip_readqc` | `boolean` | `false` | Skip stage 1 (seqkit/NanoPlot/Meryl/GenomeScope2). **Disables Merqury** since no Meryl DB is built. |

---

## Contamination

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `skip_contamination` | `boolean` | `false` | Skip read-level Kraken2 screening. |
| `kraken2_db` | `string` (path) | `null` | Kraken2 database directory. **Required** to actually run read screening; without it the stage is a pass-through. RAM ≈ DB size. |
| `contaminant_taxids` | `string` | `'2,2157,10239'` | Comma-separated NCBI taxids to remove from reads (default: Bacteria=2, Archaea=2157, Viruses=10239). |
| `run_fcs_gx` | `boolean` | `false` | Run NCBI FCS-GX assembly-level decontamination. |
| `fcs_gx_db` | `string` (path) | `null` | FCS-GX GX database directory (large). Required when `run_fcs_gx` is set. |
| `fcs_gx_tax_id` | `integer` | `null` | NCBI taxon id of your organism, used by FCS-GX to distinguish self from contaminant. |

---

## Assembly

| Parameter | Type | Default | Allowed | Description |
|-----------|------|---------|---------|-------------|
| `assembler` | `string` | `'hifiasm'` | `hifiasm`, `verkko`, `flye` | Choice of assembler. `hifiasm` for HiFi(±ONT±Hi-C); `verkko` for HiFi+ONT graph assembly; `flye` for HiFi *or* ONT alone. |
| `flye_mode` | `string` | `'--pacbio-hifi'` | `--pacbio-hifi`, `--nano-hq`, `--nano-raw`, … | Read-type flag passed to Flye. Match it to the reads you feed Flye. |

---

## purge_dups

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `skip_purgedups` | `boolean` | `false` | Skip haplotype-duplicate purging. Leave **off** for heterozygous diploids (high BUSCO Duplicated otherwise). |

---

## Scaffolding

| Parameter | Type | Default | Allowed | Description |
|-----------|------|---------|---------|-------------|
| `scaffolder` | `string` | `'yahs'` | `yahs`, `salsa` | Hi-C scaffolder. `yahs` is the default; `salsa` uses `hic_enzyme`. |
| `skip_scaffolding` | `boolean` | `false` | | Stop at contigs (no chromosome-scale scaffolds / AGP). |
| `hic_enzyme` | `string` | `null` | e.g. `GATC`, `Arima`, `DNASE` | Restriction enzyme/preset for SALSA2. |
| `min_contig_length` | `integer` | `1000` | | Minimum contig length carried into scaffolding/reporting. |

---

## Polishing

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `run_polishing` | `boolean` | `false` | Enable Racon long-read polishing. Off by default (HiFi is usually already high-QV). Turn on if Merqury QV is below target. |

---

## QC / benchmark

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `busco_lineage` | `string` | `'auto'` | BUSCO lineage. `auto` runs auto-lineage selection; otherwise an explicit clade such as `vertebrata_odb10`, `insecta_odb10`, `embryophyta_odb10`. Pick the closest clade for non-model organisms. |
| `busco_mode` | `string` | `'genome'` | BUSCO mode: `genome`, `transcriptome`, or `proteins`. |
| `busco_db` | `string` (path) | `null` | Pre-downloaded BUSCO lineage path for offline runs. |
| `skip_busco` | `boolean` | `false` | Skip BUSCO entirely. |
| `telomere_motif` | `string` | `'AACCCT'` | Telomere repeat unit searched by TIDK. Common alternatives: `TTAGGG` (vertebrates), `TTTAGGG` (many plants). |
| `tidk_clade` | `string` | `null` | TIDK clade preset; if set, overrides `telomere_motif`. |

---

## Resources & execution

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `max_cpus` | `integer` | `16` | Per-process CPU cap. Raise for large genomes. |
| `max_memory` | `string` | `'128.GB'` | Per-process memory cap. Use `'500.GB'`+ for vertebrate `hifiasm`/`verkko`. |
| `max_time` | `string` | `'240.h'` | Per-process walltime cap. |
| `publish_dir_mode` | `string` | `'copy'` | How results are published: `copy`, `symlink`, or `link`. |

---

## Validation / generic (nf-schema)

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `validate_params` | `boolean` | `true` | Validate all parameters against `nextflow_schema.json` before running. |
| `help` | `boolean` | `false` | Print the help message and exit. |
| `version` | `boolean` | `false` | Print the pipeline version and exit. |
| `monochrome_logs` | `boolean` | `false` | Disable ANSI colors in logs (useful for log files). |
| `trace_report_suffix` | `string` | run timestamp | Suffix appended to trace/timeline/report filenames in `pipeline_info/`. |

---

## Parameter interactions & gotchas

- **`skip_readqc` disables Merqury:** Merqury needs the Meryl DB built in stage 1. If you skip read QC, the QV/spectra-cn outputs are not produced.
- **Contamination screening needs a DB:** `--skip_contamination false` alone does nothing without `--kraken2_db`. The README flow uses `(!skip_contamination && kraken2_db)` to decide whether to clean reads.
- **FCS-GX needs all three:** `--run_fcs_gx`, `--fcs_gx_db`, and `--fcs_gx_tax_id` must all be set.
- **Assembler vs reads:** `verkko` expects HiFi **and** ONT; `flye` takes one read type — set `--flye_mode` to match; `hifiasm` centers on HiFi and optionally consumes ONT (`--ul`) and Hi-C (`--h1/--h2`).
- **Scaffolding needs Hi-C:** with no `hic_1`/`hic_2`, scaffolding has nothing to act on; set `--skip_scaffolding` to stop cleanly at contigs.
- **`salsa` uses the enzyme:** set `--hic_enzyme` when `--scaffolder salsa`.

---

See also: [usage](usage.md) · [outputs](output.md) · [interpretation](interpretation.md) · [README](../README.md)
