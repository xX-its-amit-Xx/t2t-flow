#!/usr/bin/env bash
#
# Recipe 01 - Heterozygous eukaryote (banana weevil, Cosmopolites sordidus)
# HiFi-only -> hifiasm assembly -> purge_dups
#
# Usage:
#   bash commands.sh stub      # dry-run the whole DAG, no data, no containers
#   bash commands.sh download  # fetch the verified public HiFi reads into ./data
#   bash commands.sh run       # run the pipeline for real
#
# All commands are copy-pasteable. The script cd's into its own directory so the
# relative paths in samplesheet.csv resolve correctly.

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$HERE"

# Repository root is two levels up from this recipe folder.
ROOT="$(cd "$HERE/../.." && pwd)"

# ---------------------------------------------------------------------------
# Verified public dataset
#   Organism : Cosmopolites sordidus (banana weevil) - a highly heterozygous,
#              non-model coleopteran. Genome ~0.6 Gbp.
#   Run      : SRR18555109  (PacBio Sequel II HiFi, ~25.8 Gbp, 1,709,178 reads)
#   Project  : PRJNA817621
#   Source   : https://www.ebi.ac.uk/ena/browser/view/SRR18555109
# ---------------------------------------------------------------------------
SRA_RUN="SRR18555109"

cmd="${1:-help}"

case "$cmd" in

  download)
    mkdir -p data
    # Direct, resumable download of the gzipped FASTQ from the ENA FTP mirror.
    # ENA serves SRA runs as ready-made fastq.gz - no sra-tools / fasterq-dump needed.
    # Path layout: vol1/fastq/<first6>/<00+last2digits>/<run>/<run>.fastq.gz
    # Verified ENA filereport: the run is served as *_subreads.fastq.gz (HiFi reads).
    URL="https://ftp.sra.ebi.ac.uk/vol1/fastq/SRR185/009/${SRA_RUN}/${SRA_RUN}_subreads.fastq.gz"
    echo "Downloading ${SRA_RUN} from ${URL}"
    wget -c -O "data/${SRA_RUN}.fastq.gz" "$URL"
    echo "Download complete:"
    ls -lh "data/${SRA_RUN}.fastq.gz"
    ;;

  stub)
    # Dry-run the entire DAG with no containers and no real data.
    # This is exactly what CI runs; do it first to validate your environment.
    nextflow run "$ROOT" -profile test,docker -stub-run
    ;;

  run)
    # Real run. HiFi-only, so scaffolding and Hi-C are not used.
    # We keep purge_dups ON (the whole point of this recipe) and skip the
    # Hi-C scaffolding stage. BUSCO lineage is set to the insect ODB set.
    nextflow run "$ROOT" \
      -profile docker \
      --input "$HERE/samplesheet.csv" \
      --outdir "$HERE/results" \
      --assembler hifiasm \
      --kmer_size 21 \
      --ploidy 2 \
      --busco_lineage endopterygota_odb10 \
      --busco_mode genome \
      --skip_scaffolding \
      --skip_contamination \
      -resume
    ;;

  *)
    echo "Usage: bash commands.sh {stub|download|run}"
    exit 1
    ;;
esac
