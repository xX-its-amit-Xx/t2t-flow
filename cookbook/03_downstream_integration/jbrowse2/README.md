# JBrowse 2 — visualising a t2t-flow assembly

Wire the recipe-02 zebra-finch scaffolds into a JBrowse 2 viewer with four things on
screen together:

1. the **assembly** (indexed FASTA),
2. a **telomere-repeat density** quantitative track (from t2t-flow's `tidk` bedgraph),
3. an **annotation** track (GFF3 — e.g. the output of recipe 03B / genomeannotator),
4. the **Hi-C contact map** (`.hic`).

Files in this folder:

| File | What it is |
|---|---|
| `commands.sh` | copy-pasteable end-to-end CLI (install → create → add tracks → index → serve) |
| `config.json` | a hand-written, ready reference config showing the exact track wiring |

---

## Prerequisites

```bash
# JBrowse 2 CLI (Node 16+)
npm install -g @jbrowse/cli
jbrowse --version

# helpers used to prep tracks
#   samtools (faidx), tabix+bgzip (htslib), bedGraphToBigWig (UCSC tools)
#   jb2 itself only needs them at prep time, not to serve
```

You also need, from recipe 02:

```
bTaeGut2_scaffolds_final.fa          # the assembly
bTaeGut2.tidk.bedgraph               # qc_benchmark/tidk/*.bedgraph
bTaeGut2.genes.gff3                  # optional: genomeannotator output (recipe 03B)
bTaeGut2.hic                         # optional: a .hic made from the YaHS alignments
```

`commands.sh` references these by relative path; copy/symlink them into this folder
first (or edit the paths).

---

## The walk-through

### 1. Scaffold a viewer and add the assembly

```bash
jbrowse create jbrowse2_data
cd jbrowse2_data
cp ../bTaeGut2_scaffolds_final.fa .

samtools faidx bTaeGut2_scaffolds_final.fa          # makes the .fai JBrowse needs

jbrowse add-assembly bTaeGut2_scaffolds_final.fa \
  --type indexedFasta \
  --name bTaeGut2 \
  --displayName "Zebra finch (bTaeGut2, t2t-flow)" \
  --load copy
```

`--type indexedFasta` + `--load copy` tells JBrowse to copy the FASTA and use the
adjacent `.fai`. The assembly **name `bTaeGut2`** is what every `add-track` below
references via `--assemblyNames`.

### 2. Telomere density track (tidk bedgraph → bigwig)

JBrowse renders quantitative data best from **bigwig**. Convert the t2t-flow `tidk`
bedgraph using a `chrom.sizes` derived from the FASTA index:

```bash
cut -f1,2 bTaeGut2_scaffolds_final.fa.fai > bTaeGut2.chrom.sizes
sort -k1,1 -k2,2n ../bTaeGut2.tidk.bedgraph > bTaeGut2.tidk.sorted.bedgraph
bedGraphToBigWig bTaeGut2.tidk.sorted.bedgraph bTaeGut2.chrom.sizes bTaeGut2.tidk.bw

jbrowse add-track bTaeGut2.tidk.bw \
  --assemblyNames bTaeGut2 \
  --trackId tidk_telomere \
  --name "Telomere repeat density (tidk AACCCT)" \
  --category "t2t-flow QC" \
  --load copy
```

In the browser this is the track you scan along each scaffold to **see telomere spikes
at the ends** — the visual confirmation of the recipe-02 telomere table.

### 3. Annotation track (GFF3 → sorted, bgzip, tabix)

```bash
# sort, compress, index (required by JBrowse's Gff3TabixAdapter)
( grep '^"#"' ../bTaeGut2.genes.gff3; grep -v '^"#"' ../bTaeGut2.genes.gff3 | sort -k1,1 -k4,4n ) \
  | bgzip > bTaeGut2.genes.sorted.gff3.gz
tabix -p gff bTaeGut2.genes.sorted.gff3.gz

jbrowse add-track bTaeGut2.genes.sorted.gff3.gz \
  --assemblyNames bTaeGut2 \
  --trackId genes \
  --name "Gene models (genomeannotator)" \
  --category "Annotation" \
  --load copy
```

> If you do not have an annotation yet, run [recipe 03B](../genomeannotator/README.md)
> first, or skip this track — the browser still works.

### 4. Hi-C contact map (.hic)

If you generated a `.hic` from the YaHS alignments (e.g. via `juicer pre`):

```bash
jbrowse add-track ../bTaeGut2.hic \
  --assemblyNames bTaeGut2 \
  --trackId hic_contacts \
  --name "Hi-C contact map (Arima)" \
  --type HicAdapter \
  --category "Scaffolding evidence" \
  --load copy
```

The Hi-C track lets you reproduce the **contact-map curation** from recipe 02 §4b right
in the browser: strong diagonal within scaffolds, clean blocks, no interior breaks.

### 5. Build the search index and serve

```bash
jbrowse text-index --assemblies bTaeGut2 --force   # gene name/ID search box
npx serve .                                        # http://localhost:3000
```

Open the URL, pick assembly **bTaeGut2**, and "Open track selector" to toggle the four
tracks. Jump to the largest scaffold and confirm: gene density, telomere spikes at both
ends, and a clean Hi-C diagonal.

---

## What good looks like in the browser

* **Telomere track**: tall spikes hugging the 5′ and 3′ extremities of each large
  scaffold; flat in the middle. Interior spikes ⇒ suspected mis-join (cross-check Hi-C).
* **Hi-C track**: bright diagonal, per-chromosome square blocks, faint off-diagonal.
* **Genes**: even gene density across the chromosome; sudden gene-poor deserts can be
  centromeric/satellite regions — cross-check the telomere/centromere table.

See `config.json` for the literal JSON these CLI calls produce.
