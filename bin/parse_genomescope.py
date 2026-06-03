#!/usr/bin/env python3
"""
parse_genomescope.py — extract key estimates from a GenomeScope2 summary.

Part of the t2t-flow pipeline (GPLv3).

GenomeScope2 writes a `*_summary.txt` file whose body is a small fixed-width
table of property / min / max columns, e.g.:

    GenomeScope version 2.0
    k = 21

    property                      min               max
    Homozygous (aa)               98.7654%          98.9012%
    Heterozygous (ab)             1.0988%           1.2346%
    Genome Haploid Length         1,234,567 bp      1,240,000 bp
    Genome Repeat Length          234,567 bp        240,000 bp
    Genome Unique Length          1,000,000 bp      1,005,000 bp
    Model Fit                     96.5432%          98.7654%
    Read Error Rate               0.1234%           0.1300%

This script parses that table into a normalized JSON document with estimated
genome size (the max of the haploid length range is reported as the primary
estimate, with min/max retained), heterozygosity, model fit, read error rate,
the k-mer size, and the ploidy used. It is robust to absent or malformed files.
"""

import argparse
import json
import re
import sys


def eprint(*args, **kwargs):
    print(*args, file=sys.stderr, **kwargs)


def _strip_units(token):
    """Strip thousands separators and unit suffixes ('bp', '%') from a token."""
    if token is None:
        return None
    token = token.strip()
    token = token.replace(",", "")
    token = re.sub(r"\s*bp\s*$", "", token, flags=re.IGNORECASE)
    is_percent = token.endswith("%")
    token = token.rstrip("%").strip()
    if token == "":
        return None
    try:
        value = float(token)
    except ValueError:
        return None
    return value, is_percent


def _num(token):
    parsed = _strip_units(token)
    if parsed is None:
        return None
    return parsed[0]


def parse_summary(path):
    """Parse a GenomeScope2 *_summary.txt into a dict of min/max ranges."""
    data = {
        "k": None,
        "ploidy": None,
        "homozygous_percent": {"min": None, "max": None},
        "heterozygous_percent": {"min": None, "max": None},
        "genome_haploid_length": {"min": None, "max": None},
        "genome_repeat_length": {"min": None, "max": None},
        "genome_unique_length": {"min": None, "max": None},
        "model_fit_percent": {"min": None, "max": None},
        "read_error_rate_percent": {"min": None, "max": None},
    }

    try:
        fh = open(path)
    except (FileNotFoundError, TypeError):
        eprint(f"[parse_genomescope] WARNING: summary not found: {path}")
        return data

    # Map textual property labels to our normalized keys.
    label_keys = [
        (r"homozygous", "homozygous_percent"),
        (r"heterozygous", "heterozygous_percent"),
        (r"genome\s+haploid\s+length", "genome_haploid_length"),
        (r"genome\s+repeat\s+length", "genome_repeat_length"),
        (r"genome\s+unique\s+length", "genome_unique_length"),
        (r"model\s+fit", "model_fit_percent"),
        (r"read\s+error\s+rate", "read_error_rate_percent"),
    ]

    with fh:
        for raw in fh:
            line = raw.rstrip("\n")
            if not line.strip():
                continue

            # k = 21
            km = re.search(r"\bk\s*=\s*(\d+)", line)
            if km:
                data["k"] = int(km.group(1))
                continue

            # ploidy / p = 2  (GenomeScope2 prints 'p = 2' in some versions)
            pm = re.search(r"\b(?:ploidy|p)\s*=\s*(\d+)", line, flags=re.IGNORECASE)
            if pm:
                data["ploidy"] = int(pm.group(1))
                continue

            # Property rows: label then up to two numeric (min,max) tokens.
            matched_key = None
            for pattern, key in label_keys:
                if re.search(pattern, line, flags=re.IGNORECASE):
                    matched_key = key
                    break
            if matched_key is None:
                continue

            # Extract numeric tokens (with optional commas / units).
            tokens = re.findall(r"[-+]?[\d,]+(?:\.\d+)?\s*(?:bp|%)?", line)
            # The first token may be part of the label if label contains digits;
            # filter to those that resemble numbers.
            numeric = []
            for t in tokens:
                v = _num(t)
                if v is not None:
                    numeric.append(v)
            if not numeric:
                continue
            if len(numeric) == 1:
                data[matched_key]["min"] = numeric[0]
                data[matched_key]["max"] = numeric[0]
            else:
                data[matched_key]["min"] = numeric[0]
                data[matched_key]["max"] = numeric[1]

    return data


def derive_estimates(parsed, fallback_ploidy=None):
    """Produce a flat set of primary estimates for convenience."""
    haploid = parsed["genome_haploid_length"]
    het = parsed["heterozygous_percent"]
    fit = parsed["model_fit_percent"]
    err = parsed["read_error_rate_percent"]

    # Primary genome size estimate: prefer max of haploid range; fall back to min.
    genome_size = haploid["max"] if haploid["max"] is not None else haploid["min"]

    estimates = {
        "estimated_genome_size_bp": (
            int(genome_size) if genome_size is not None else None
        ),
        "genome_size_min_bp": (
            int(haploid["min"]) if haploid["min"] is not None else None
        ),
        "genome_size_max_bp": (
            int(haploid["max"]) if haploid["max"] is not None else None
        ),
        "heterozygosity_percent": het["max"] if het["max"] is not None else het["min"],
        "model_fit_percent": fit["max"] if fit["max"] is not None else fit["min"],
        "read_error_rate_percent": err["max"] if err["max"] is not None else err["min"],
        "kmer_size": parsed["k"],
        "ploidy": parsed["ploidy"] if parsed["ploidy"] is not None else fallback_ploidy,
    }
    return estimates


def main(argv=None):
    parser = argparse.ArgumentParser(
        description="Parse a GenomeScope2 *_summary.txt into JSON."
    )
    parser.add_argument("--summary", required=True,
                        help="GenomeScope2 *_summary.txt input.")
    parser.add_argument("--out", required=True,
                        help="Output JSON path.")
    parser.add_argument("--ploidy", type=int, default=None,
                        help="Ploidy used for the run (fallback if not in file).")
    parser.add_argument("--sample", default=None,
                        help="Optional sample identifier to embed.")
    args = parser.parse_args(argv)

    parsed = parse_summary(args.summary)
    estimates = derive_estimates(parsed, fallback_ploidy=args.ploidy)

    report = {
        "schema_version": "1.0",
        "tool": "parse_genomescope.py",
        "sample": args.sample or "",
        "input": args.summary,
        "estimates": estimates,
        "raw_ranges": parsed,
    }

    with open(args.out, "w") as fh:
        json.dump(report, fh, indent=2)
        fh.write("\n")

    eprint(f"[parse_genomescope] wrote {args.out} "
           f"(genome size estimate: {estimates['estimated_genome_size_bp']} bp)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
