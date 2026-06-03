# Recipe 03 — Downstream integration (visualisation + annotation hand-off)

You have a curated, chromosome-scale assembly from [recipe 02](../02_hic_scaffolding/README.md)
(`bTaeGut2_scaffolds_final.fa` + `.agp`) and the QC tracks t2t-flow produced (tidk
telomere bedgraph, etc.). This recipe wires those outputs into two real downstream
tools:

1. **[JBrowse 2](jbrowse2/)** — a genome browser to *see* the assembly, the telomere
   density track, an annotation (GFF3), and the Hi-C contact map together.
2. **[nf-core/genomeannotator](genomeannotator/)** — to *annotate* the scaffolds
   (gene structures), with a concrete `params.yaml` mapping t2t-flow outputs onto its
   inputs.

Everything here is post-assembly and cheap (minutes, <8 GB RAM). All commands are
copy-pasteable.

---

## What t2t-flow gives you to hand off

| t2t-flow output (recipe 02) | Path under `results/` | Used by |
|---|---|---|
| Scaffolds FASTA | `scaffolding/yahs/bTaeGut2_scaffolds_final.fa` | JBrowse assembly, genomeannotator `--assembly` |
| Scaffolds AGP | `scaffolding/yahs/bTaeGut2_scaffolds_final.agp` | provenance; JBrowse gap track (optional) |
| Telomere bedgraph | `qc_benchmark/tidk/*.bedgraph` | JBrowse quantitative track |
| Telomere/centromere table | `qc_benchmark/tidk/*.telomere_centromere.{tsv,json}` | curation notes |
| Assembly stats JSON | `release/*.assembly_stats.json` | record / dashboards |

> The scaffolds FASTA is the **single source of truth** for downstream coordinates.
> Annotate **the same FASTA** you visualise, or coordinates will not line up.

---

## A) Visualise in JBrowse 2

See [`jbrowse2/README.md`](jbrowse2/README.md) for the full walk-through and
[`jbrowse2/commands.sh`](jbrowse2/commands.sh) for the runnable CLI. In short:

```bash
npm install -g @jbrowse/cli            # one-time
jbrowse create jbrowse2_data           # scaffold a viewer
cd jbrowse2_data

# assembly (indexed FASTA)
samtools faidx bTaeGut2_scaffolds_final.fa
jbrowse add-assembly bTaeGut2_scaffolds_final.fa \
  --type indexedFasta --name bTaeGut2 --load copy

# telomere density (bigwig), annotation (gff3.gz tabix), Hi-C (.hic) ... see commands.sh
jbrowse text-index --assemblies bTaeGut2 --force
npx serve .                            # open http://localhost:3000
```

A ready-made [`jbrowse2/config.json`](jbrowse2/config.json) is provided so you can see
the exact track wiring even before running the CLI.

---

## B) Annotate with nf-core/genomeannotator

See [`genomeannotator/README.md`](genomeannotator/README.md) and the concrete
[`genomeannotator/params.yaml`](genomeannotator/params.yaml). The hand-off is a single
mapping: t2t-flow's **scaffolds FASTA → genomeannotator `--assembly`**, plus an evidence
set (related-organism proteins, transcripts, optional RNA-seq). In short:

```bash
nextflow run nf-core/genomeannotator -r 1.0 \
  -profile docker \
  -params-file params.yaml
```

The telomere/centromere table from t2t-flow tells the annotator where the
chromosome-scale, finished regions are — annotate confidently there, treat unplaced
fragments with more caution.

---

## Coordinate hygiene (read this once)

* **One FASTA, one coordinate system.** Use the *exact* `bTaeGut2_scaffolds_final.fa`
  (same scaffold names, same order) everywhere. Re-running scaffolding can rename
  scaffolds — re-export tracks if you do.
* **Sort + compress + index** any GFF3 before loading into JBrowse (`bgzip` + `tabix`),
  or JBrowse will refuse it. `commands.sh` shows the one-liner.
* **bedgraph → bigwig.** JBrowse prefers bigwig for quantitative data;
  `bedGraphToBigWig` needs a `chrom.sizes` derived from the `.fai` (shown in
  `jbrowse2/commands.sh`).
