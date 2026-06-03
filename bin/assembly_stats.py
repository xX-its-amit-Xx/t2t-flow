#!/usr/bin/env python3
"""
assembly_stats.py — aggregate per-assembly QC artifacts into one JSON report.

Part of the t2t-flow pipeline (GPLv3).

Collects results from several upstream tools into a single machine-readable
`*.assembly_stats.json`:

  * gfastats text report  -> N50, total length, #contigs/#scaffolds, GC%, largest
  * BUSCO short_summary.json -> C / S / D / F / M percentages and lineage
  * Merqury .qv            -> consensus quality value (QV)
  * tidk search TSV        -> number of telomere-bearing sequences
  * telomere_table.json    -> T2T (both-ends) sequence counts & centromere candidates

Every input is optional (argparse flags). Missing inputs simply leave the
corresponding fields null, so the script runs cleanly under `-stub-run` when its
upstream channels are empty.

The output JSON carries a `schema_version` field and a human-readable
`summary` string suitable for logs or a MultiQC custom-content section.
"""

import argparse
import json
import re
import sys


SCHEMA_VERSION = "1.0"


def eprint(*args, **kwargs):
    print(*args, file=sys.stderr, **kwargs)


def _safe_open(path):
    if not path:
        return None
    try:
        return open(path)
    except FileNotFoundError:
        eprint(f"[assembly_stats] WARNING: file not found: {path}")
        return None


def _to_number(text):
    """Convert a possibly comma-formatted numeric string to int/float."""
    if text is None:
        return None
    text = str(text).strip().replace(",", "")
    if text == "":
        return None
    try:
        if re.fullmatch(r"[-+]?\d+", text):
            return int(text)
        return float(text)
    except ValueError:
        return None


def parse_gfastats(path):
    """Parse a gfastats text report into a dict.

    gfastats emits lines like 'Total scaffold length: 1234567' and
    'Scaffold N50: 987654'. We match a set of known labels case-insensitively.
    """
    result = {
        "total_length": None,
        "num_contigs": None,
        "num_scaffolds": None,
        "n50": None,
        "largest": None,
        "gc_percent": None,
    }
    fh = _safe_open(path)
    if fh is None:
        return result

    label_map = [
        (r"total\s+scaffold\s+length", "total_length"),
        (r"total\s+contig\s+length", "total_length_contig"),
        (r"^\s*total\s+length", "total_length"),
        (r"scaffold\s+n50", "n50"),
        (r"contig\s+n50", "n50_contig"),
        (r"^\s*n50", "n50"),
        (r"#\s*scaffolds", "num_scaffolds"),
        (r"number\s+of\s+scaffolds", "num_scaffolds"),
        (r"#\s*contigs", "num_contigs"),
        (r"number\s+of\s+contigs", "num_contigs"),
        (r"largest\s+scaffold", "largest"),
        (r"largest\s+contig", "largest_contig"),
        (r"^\s*largest", "largest"),
        (r"gc\s*content", "gc_percent"),
        (r"gc\s*%", "gc_percent"),
        (r"^\s*gc\b", "gc_percent"),
    ]

    extras = {}
    with fh:
        for raw in fh:
            line = raw.rstrip("\n")
            if not line or ":" not in line:
                continue
            label, _, value = line.partition(":")
            value = value.strip()
            num = _to_number(value)
            for pattern, key in label_map:
                if re.search(pattern, label, flags=re.IGNORECASE):
                    extras[key] = num
                    break

    # Resolve preferred keys with sensible fallbacks (scaffold-level preferred).
    result["total_length"] = extras.get("total_length",
                                        extras.get("total_length_contig"))
    result["n50"] = extras.get("n50", extras.get("n50_contig"))
    result["num_scaffolds"] = extras.get("num_scaffolds")
    result["num_contigs"] = extras.get("num_contigs")
    result["largest"] = extras.get("largest", extras.get("largest_contig"))
    result["gc_percent"] = extras.get("gc_percent")
    return result


def parse_busco_json(path):
    """Parse a BUSCO short_summary JSON into C/S/D/F/M and lineage."""
    result = {
        "lineage": None,
        "complete": None,
        "single_copy": None,
        "duplicated": None,
        "fragmented": None,
        "missing": None,
        "n_markers": None,
    }
    fh = _safe_open(path)
    if fh is None:
        return result
    with fh:
        try:
            data = json.load(fh)
        except (json.JSONDecodeError, ValueError):
            eprint(f"[assembly_stats] WARNING: invalid BUSCO json: {path}")
            return result

    # BUSCO 5.x short_summary.json structure: 'results' + 'lineage_dataset'.
    results = data.get("results", data)
    lineage_block = data.get("lineage_dataset", {})
    if isinstance(lineage_block, dict):
        result["lineage"] = lineage_block.get("name")

    def pick(*keys):
        for k in keys:
            if k in results and results[k] is not None:
                return results[k]
        return None

    result["complete"] = _to_number(pick("Complete percentage", "Complete"))
    result["single_copy"] = _to_number(
        pick("Single copy percentage", "Single copy"))
    result["duplicated"] = _to_number(
        pick("Multi copy percentage", "Duplicated", "Multi copy"))
    result["fragmented"] = _to_number(
        pick("Fragmented percentage", "Fragmented"))
    result["missing"] = _to_number(pick("Missing percentage", "Missing"))
    result["n_markers"] = _to_number(
        pick("n_markers", "Number of markers", "Total"))
    return result


def parse_merqury_qv(path):
    """Parse a Merqury .qv file; return the (last) assembly QV as float.

    A merqury .qv line is: asm  uniqueKmers  totalKmers  QV  errorRate
    """
    fh = _safe_open(path)
    if fh is None:
        return None
    qv = None
    with fh:
        for raw in fh:
            line = raw.strip()
            if not line or line.startswith("#"):
                continue
            fields = re.split(r"\s+", line)
            if len(fields) >= 4:
                candidate = _to_number(fields[3])
                if candidate is not None:
                    qv = candidate
    return qv


def count_tidk_telomeric_sequences(path):
    """Count sequences with any telomeric repeat in a tidk search TSV/CSV."""
    fh = _safe_open(path)
    if fh is None:
        return None
    telomeric_seqs = set()
    with fh:
        header = None
        for raw in fh:
            line = raw.rstrip("\n")
            if not line:
                continue
            if "\t" in line and line.count("\t") >= line.count(","):
                fields = line.split("\t")
            else:
                fields = line.split(",")
            if header is None:
                lowered = [f.strip().lower() for f in fields]
                if any(h in lowered for h in
                       ("id", "window", "telomeric_repeat",
                        "forward_repeat_number")):
                    header = lowered
                    continue
                header = ["id", "window", "forward_repeat_number",
                          "reverse_repeat_number", "telomeric_repeat"]
            # parse positionally / by header
            def col(name, default_idx):
                idx = header.index(name) if name in header else default_idx
                return fields[idx].strip() if idx < len(fields) else ""

            seq = col("id", 0)
            fwd = _to_number(col("forward_repeat_number", 2)) or 0
            rev = _to_number(col("reverse_repeat_number", 3)) or 0
            if seq and (fwd + rev) > 0:
                telomeric_seqs.add(seq)
    return len(telomeric_seqs)


def parse_telomere_table(path):
    """Pull T2T / centromere summary out of telomere_table.py JSON output."""
    result = {
        "n_sequences": None,
        "n_t2t_both_ends": None,
        "n_one_end_telomeric": None,
        "n_centromere_candidates": None,
    }
    fh = _safe_open(path)
    if fh is None:
        return result
    with fh:
        try:
            data = json.load(fh)
        except (json.JSONDecodeError, ValueError):
            eprint(f"[assembly_stats] WARNING: invalid telomere json: {path}")
            return result
    summary = data.get("summary", {})
    for key in result:
        if key in summary:
            result[key] = summary[key]
    return result


def build_summary_string(sample, gfa, busco, qv, tidk_n, telo):
    parts = [f"Assembly '{sample}':"]
    if gfa.get("total_length"):
        parts.append(f"total length {gfa['total_length']:,} bp")
    if gfa.get("n50"):
        parts.append(f"N50 {gfa['n50']:,} bp")
    if gfa.get("num_scaffolds") is not None:
        parts.append(f"{gfa['num_scaffolds']} scaffolds")
    elif gfa.get("num_contigs") is not None:
        parts.append(f"{gfa['num_contigs']} contigs")
    if busco.get("complete") is not None:
        lineage = busco.get("lineage") or "lineage"
        parts.append(f"BUSCO C:{busco['complete']}% ({lineage})")
    if qv is not None:
        parts.append(f"Merqury QV {qv}")
    if telo.get("n_t2t_both_ends") is not None:
        parts.append(f"{telo['n_t2t_both_ends']} T2T (both-end telomere) seqs")
    elif tidk_n is not None:
        parts.append(f"{tidk_n} telomere-bearing seqs")
    return "; ".join(parts) + "."


def main(argv=None):
    parser = argparse.ArgumentParser(
        description="Aggregate assembly QC artifacts into a single JSON report."
    )
    parser.add_argument("--sample", default="assembly",
                        help="Sample / assembly identifier (meta.id).")
    parser.add_argument("--gfastats", default=None,
                        help="gfastats text report.")
    parser.add_argument("--busco-json", dest="busco_json", default=None,
                        help="BUSCO short_summary JSON.")
    parser.add_argument("--merqury-qv", dest="merqury_qv", default=None,
                        help="Merqury .qv file.")
    parser.add_argument("--tidk-search", dest="tidk_search", default=None,
                        help="tidk search TSV/CSV.")
    parser.add_argument("--telomere-json", dest="telomere_json", default=None,
                        help="telomere_table.py JSON output.")
    parser.add_argument("--out", required=True,
                        help="Output assembly_stats JSON path.")
    args = parser.parse_args(argv)

    # pandas is part of the container contract; import defensively.
    try:
        import pandas  # noqa: F401
        _have_pandas = True
    except Exception:  # pragma: no cover
        _have_pandas = False

    gfa = parse_gfastats(args.gfastats)
    busco = parse_busco_json(args.busco_json)
    qv = parse_merqury_qv(args.merqury_qv)
    tidk_n = count_tidk_telomeric_sequences(args.tidk_search)
    telo = parse_telomere_table(args.telomere_json)

    report = {
        "schema_version": SCHEMA_VERSION,
        "tool": "assembly_stats.py",
        "sample": args.sample,
        "inputs": {
            "gfastats": args.gfastats or "",
            "busco_json": args.busco_json or "",
            "merqury_qv": args.merqury_qv or "",
            "tidk_search": args.tidk_search or "",
            "telomere_json": args.telomere_json or "",
            "pandas_available": _have_pandas,
        },
        "contiguity": gfa,
        "busco": busco,
        "merqury_qv": qv,
        "telomeres": {
            "telomere_bearing_sequences": tidk_n,
            "n_sequences": telo.get("n_sequences"),
            "n_t2t_both_ends": telo.get("n_t2t_both_ends"),
            "n_one_end_telomeric": telo.get("n_one_end_telomeric"),
            "n_centromere_candidates": telo.get("n_centromere_candidates"),
        },
    }
    report["summary"] = build_summary_string(
        args.sample, gfa, busco, qv, tidk_n, report["telomeres"])

    with open(args.out, "w") as fh:
        json.dump(report, fh, indent=2)
        fh.write("\n")

    eprint(f"[assembly_stats] wrote {args.out}")
    eprint(f"[assembly_stats] {report['summary']}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
