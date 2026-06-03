#!/usr/bin/env bash
#
# JBrowse 2 - load a t2t-flow assembly + telomere track + annotation + Hi-C.
# Copy-pasteable end to end. Run from this directory.
#
# Inputs expected in this folder (copy/symlink from recipe 02 results first):
#   bTaeGut2_scaffolds_final.fa     (scaffolding/yahs/...)
#   bTaeGut2.tidk.bedgraph          (qc_benchmark/tidk/*.bedgraph)
#   bTaeGut2.genes.gff3             (optional, from recipe 03B / genomeannotator)
#   bTaeGut2.hic                    (optional, .hic made from YaHS alignments)

set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$HERE"

ASM="bTaeGut2_scaffolds_final.fa"
ASM_NAME="bTaeGut2"

# 0. one-time install
#   npm install -g @jbrowse/cli
#   (also need: samtools, htslib's bgzip+tabix, UCSC bedGraphToBigWig)

# 1. scaffold a viewer and add the assembly -------------------------------
jbrowse create jbrowse2_data || true     # no-op if it already exists
cp -f "$ASM" jbrowse2_data/ 2>/dev/null || true
cd jbrowse2_data
[ -f "$ASM" ] || cp "../$ASM" .

samtools faidx "$ASM"

jbrowse add-assembly "$ASM" \
  --type indexedFasta \
  --name "$ASM_NAME" \
  --displayName "Zebra finch (bTaeGut2, t2t-flow)" \
  --load copy \
  --overwrite

# 2. telomere density: tidk bedgraph -> bigwig ----------------------------
if [ -f "../bTaeGut2.tidk.bedgraph" ]; then
  cut -f1,2 "${ASM}.fai" > bTaeGut2.chrom.sizes
  sort -k1,1 -k2,2n ../bTaeGut2.tidk.bedgraph > bTaeGut2.tidk.sorted.bedgraph
  bedGraphToBigWig bTaeGut2.tidk.sorted.bedgraph bTaeGut2.chrom.sizes bTaeGut2.tidk.bw
  jbrowse add-track bTaeGut2.tidk.bw \
    --assemblyNames "$ASM_NAME" \
    --trackId tidk_telomere \
    --name "Telomere repeat density (tidk AACCCT)" \
    --category "t2t-flow QC" \
    --load copy --overwrite
fi

# 3. annotation: gff3 -> sorted + bgzip + tabix ---------------------------
if [ -f "../bTaeGut2.genes.gff3" ]; then
  ( grep '^#' ../bTaeGut2.genes.gff3; grep -v '^#' ../bTaeGut2.genes.gff3 | sort -k1,1 -k4,4n ) \
    | bgzip > bTaeGut2.genes.sorted.gff3.gz
  tabix -p gff bTaeGut2.genes.sorted.gff3.gz
  jbrowse add-track bTaeGut2.genes.sorted.gff3.gz \
    --assemblyNames "$ASM_NAME" \
    --trackId genes \
    --name "Gene models (genomeannotator)" \
    --category "Annotation" \
    --load copy --overwrite
fi

# 4. Hi-C contact map (.hic) ----------------------------------------------
if [ -f "../bTaeGut2.hic" ]; then
  jbrowse add-track ../bTaeGut2.hic \
    --assemblyNames "$ASM_NAME" \
    --trackId hic_contacts \
    --name "Hi-C contact map (Arima)" \
    --type HicAdapter \
    --category "Scaffolding evidence" \
    --load copy --overwrite
fi

# 5. search index + serve --------------------------------------------------
jbrowse text-index --assemblies "$ASM_NAME" --force
echo "Serving on http://localhost:3000  (Ctrl-C to stop)"
npx serve .
