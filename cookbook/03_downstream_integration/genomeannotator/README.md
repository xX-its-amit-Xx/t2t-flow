# Hand-off to nf-core/genomeannotator

t2t-flow stops at a **curated, chromosome-scale, masked-where-needed assembly**. The
natural next step is **structural gene annotation**. nf-core/genomeannotator is the
nf-core pipeline for "identification of (coding) gene structures in draft genomes" and
takes a single assembly FASTA plus evidence. This doc maps t2t-flow outputs onto its
inputs and gives a concrete, runnable `params.yaml`.

> **Verification note.** The parameter names below were confirmed against the
> nf-core/genomeannotator usage docs (<https://nf-co.re/genomeannotator/usage> and
> <https://nf-co.re/genomeannotator/parameters>). genomeannotator expects **one FASTA
> file per input option** (it is single-genome per run, not a samplesheet of genomes);
> only the RNA-seq evidence is supplied as a samplesheet.

---

## Input mapping (t2t-flow → genomeannotator)

| genomeannotator param | Value from t2t-flow / you provide | Notes |
|---|---|---|
| `--assembly` | `…/scaffolding/yahs/bTaeGut2_scaffolds_final.fa` | **the** t2t-flow product to annotate |
| `--outdir` | `genomeannotator_results` | your choice |
| `--proteins` | related-organism proteins FASTA (e.g. chicken/zebra-finch UniProt) | broad homology evidence |
| `--proteins_targeted` | high-confidence, organism-specific proteins FASTA (optional) | trusted seed evidence |
| `--transcripts` | assembled transcripts / ESTs FASTA (optional) | if you have them |
| `--rnaseq_samples` | RNA-seq samplesheet (`samplesheet_rnaseq.csv`) | sample,fastq_1,fastq_2,strandedness |
| `--rm_lib` | known repeat library FASTA (optional) | preferred over `--rm_species` |
| `--rm_species` | DFam species name (e.g. `aves`) | fallback if you have no `--rm_lib` |
| `--busco_lineage` | `aves_odb10` | same lineage you used in t2t-flow QC |

**Repeat masking:** t2t-flow does *not* hard-mask the assembly, so let genomeannotator
mask it. Prefer a curated `--rm_lib` (e.g. a RepeatModeler library built on the
scaffolds); otherwise `--rm_species aves` uses the built-in DFam set.

**Why the telomere/centromere table matters here:** annotate the chromosome-scale,
two-ended scaffolds (high `both_ends_telomere` in the recipe-02 table) with full
confidence; treat tiny unplaced fragments and candidate satellite/centromere bands as
lower-confidence regions when you review gene models.

---

## Concrete run

Edit `params.yaml` (paths to your evidence), then:

```bash
# from this folder
nextflow run nf-core/genomeannotator -r 1.0 \
  -profile docker \
  -params-file params.yaml
```

(Replace `-r 1.0` with the genomeannotator release you have pulled; use
`nextflow pull nf-core/genomeannotator` first. `-profile test` runs its own tiny demo
data if you just want to confirm the install.)

### RNA-seq samplesheet (`samplesheet_rnaseq.csv`)

genomeannotator's RNA-seq evidence is the only samplesheet input — four columns:

```csv
sample,fastq_1,fastq_2,strandedness
liver_rep1,/data/rnaseq/liver_rep1_R1.fastq.gz,/data/rnaseq/liver_rep1_R2.fastq.gz,reverse
brain_rep1,/data/rnaseq/brain_rep1_R1.fastq.gz,/data/rnaseq/brain_rep1_R2.fastq.gz,reverse
```

Drop the `--rnaseq_samples` line from `params.yaml` if you have no RNA-seq; protein
evidence alone still produces gene models (lower recall on UTRs/isoforms).

---

## What comes back

genomeannotator emits a **GFF3** of gene models (plus protein/CDS FASTA and a BUSCO
score on the annotated gene set). Feed that GFF3 straight back into
[JBrowse 2](../jbrowse2/README.md) as the "Gene models" track — same `bTaeGut2`
coordinate system, so it overlays the assembly and telomere track exactly.

Full loop: **t2t-flow (assembly) → genomeannotator (genes) → JBrowse2 (look at both).**
