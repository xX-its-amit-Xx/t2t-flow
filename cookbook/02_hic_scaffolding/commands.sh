#!/usr/bin/env bash
#
# Recipe 02 - Hi-C scaffolding (zebra finch, Taeniopygia guttata, GenomeArk bTaeGut2)
# HiFi -> hifiasm -> purge_dups -> YaHS Hi-C scaffolding
#
# Usage:
#   bash commands.sh stub      # dry-run the whole DAG, no data, no containers
#   bash commands.sh download  # fetch verified GenomeArk HiFi + Arima Hi-C into ./data
#   bash commands.sh run       # run the pipeline for real
#
# All commands are copy-pasteable. The script cd's into its own directory.

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$HERE"
ROOT="$(cd "$HERE/../.." && pwd)"

# ---------------------------------------------------------------------------
# Verified public dataset - GenomeArk / VGP zebra finch bTaeGut2
#   S3 bucket: s3://genomeark  (public, no-sign-request) and HTTPS mirror
#   Species page: https://www.genomeark.org/vgp-all/Taeniopygia_guttata.html
#
#   HiFi (pacbio_hifi/, verified keys, *.hifi_reads.fastq.gz):
#     m54306U_210519_154448.hifi_reads.fastq.gz
#     m54306U_210521_004211.hifi_reads.fastq.gz
#     m54306Ue_210629_211205.hifi_reads.fastq.gz
#     m54306Ue_210719_083927.hifi_reads.fastq.gz
#     m64055e_210624_223222.hifi_reads.fastq.gz
#
#   Arima Hi-C (arima/, verified keys, paired *_R1/_R2.fq.gz, 9 lanes):
#     bTaeGut2_ARI8_001_USPD16084394-AK5146_HJFMFCCXY_L1..L8_R1/R2.fq.gz
#     bTaeGut2_ARI8_001_USPD16084394-AK5146_HJFMMCCXY_L6_R1/R2.fq.gz
# ---------------------------------------------------------------------------
S3="https://genomeark.s3.amazonaws.com/species/Taeniopygia_guttata/bTaeGut2/genomic_data"

cmd="${1:-help}"

case "$cmd" in

  download)
    mkdir -p data

    echo "== HiFi (concatenate the 5 verified hifi_reads movies into one fastq.gz) =="
    HIFI=(
      "m54306U_210519_154448.hifi_reads.fastq.gz"
      "m54306U_210521_004211.hifi_reads.fastq.gz"
      "m54306Ue_210629_211205.hifi_reads.fastq.gz"
      "m54306Ue_210719_083927.hifi_reads.fastq.gz"
      "m64055e_210624_223222.hifi_reads.fastq.gz"
    )
    : > data/bTaeGut2.hifi.fastq.gz
    for f in "${HIFI[@]}"; do
      echo "  downloading $f"
      wget -c -O "data/${f}" "${S3}/pacbio_hifi/${f}"
      # gzip files concatenate cleanly into one valid gzip stream
      cat "data/${f}" >> data/bTaeGut2.hifi.fastq.gz
    done

    echo "== Arima Hi-C (concatenate the 9 lanes per mate into R1 / R2) =="
    HIC_BASE="bTaeGut2_ARI8_001_USPD16084394-AK5146"
    HIC_LANES=(
      "HJFMFCCXY_L1" "HJFMFCCXY_L2" "HJFMFCCXY_L3" "HJFMFCCXY_L4"
      "HJFMFCCXY_L5" "HJFMFCCXY_L6" "HJFMFCCXY_L7" "HJFMFCCXY_L8"
      "HJFMMCCXY_L6"
    )
    : > data/bTaeGut2.hic_R1.fastq.gz
    : > data/bTaeGut2.hic_R2.fastq.gz
    for lane in "${HIC_LANES[@]}"; do
      r1="${HIC_BASE}_${lane}_R1.fq.gz"
      r2="${HIC_BASE}_${lane}_R2.fq.gz"
      echo "  downloading $r1 / $r2"
      wget -c -O "data/${r1}" "${S3}/arima/${r1}"
      wget -c -O "data/${r2}" "${S3}/arima/${r2}"
      cat "data/${r1}" >> data/bTaeGut2.hic_R1.fastq.gz
      cat "data/${r2}" >> data/bTaeGut2.hic_R2.fastq.gz
    done

    echo "Done. Combined inputs:"
    ls -lh data/bTaeGut2.hifi.fastq.gz data/bTaeGut2.hic_R1.fastq.gz data/bTaeGut2.hic_R2.fastq.gz
    ;;

  download-aws)
    # Alternative: if you have the AWS CLI, this is faster (parallel, no-sign-request).
    mkdir -p data
    aws s3 cp --no-sign-request --recursive \
      "s3://genomeark/species/Taeniopygia_guttata/bTaeGut2/genomic_data/pacbio_hifi/" \
      data/pacbio_hifi/ --exclude "*" --include "*.hifi_reads.fastq.gz"
    aws s3 cp --no-sign-request --recursive \
      "s3://genomeark/species/Taeniopygia_guttata/bTaeGut2/genomic_data/arima/" \
      data/arima/ --exclude "*" --include "*.fq.gz"
    echo "Now concatenate movies/lanes as in the 'download' target above."
    ;;

  stub)
    nextflow run "$ROOT" -profile test,docker -stub-run
    ;;

  run)
    nextflow run "$ROOT" \
      -profile docker \
      --input "$HERE/samplesheet.csv" \
      --outdir "$HERE/results" \
      --assembler hifiasm \
      --scaffolder yahs \
      --kmer_size 21 \
      --ploidy 2 \
      --busco_lineage aves_odb10 \
      --busco_mode genome \
      --telomere_motif AACCCT \
      --hic_enzyme Arima \
      -resume
    ;;

  *)
    echo "Usage: bash commands.sh {stub|download|download-aws|run}"
    exit 1
    ;;
esac
