#!/usr/bin/env python3
"""
telomere_table.py — build a per-sequence telomere / centromere candidate table.

Part of the t2t-flow pipeline (GPLv3).

Consumes the output of `tidk search` (per-window telomeric repeat counts), a
samtools `.fai` index (for sequence lengths), and optionally a scaffolding
`.agp` file. Produces a per-sequence table describing whether telomeric repeat
arrays are present at the 5' and/or 3' ends of each sequence, the total
telomeric repeat count, and a heuristic flag for interstitial tandem-repeat
density that may indicate a (peri)centromeric region.

The script is intentionally robust to missing or empty inputs: any missing
optional file simply yields empty / default columns rather than an error so it
can be wired into a Nextflow process whose upstream artifacts may be empty under
`-stub-run`.

Outputs:
  * TSV  with columns:
        sequence, length, telomere_5prime, telomere_3prime,
        telomere_repeat_count, centromere_candidate, notes
  * JSON: a list of row objects plus a small metadata header.
"""

import argparse
import json
import sys
from collections import defaultdict


# ----------------------------------------------------------------------------
# Tunable heuristics
# ----------------------------------------------------------------------------
# Fraction of a sequence's length (from each end) that is considered "terminal"
# when deciding whether a telomeric array sits at the 5' or 3' end.
TERMINAL_FRACTION = 0.05
# Absolute terminal window cap (bp) so that the terminal region does not become
# unreasonably large on very long chromosomes.
TERMINAL_MAX_BP = 30000
# Minimum telomeric repeat count within a terminal window to call a telomere.
TELOMERE_MIN_REPEATS = 25
# Interstitial windows whose repeat count exceeds this threshold contribute to
# the centromere-candidate density score.
INTERSTITIAL_REPEAT_THRESHOLD = 10
# If the interstitial telomeric-repeat density (high-repeat interstitial windows
# divided by total interstitial windows) exceeds this, flag a candidate.
CENTROMERE_DENSITY_THRESHOLD = 0.15
# Minimum number of interstitial windows required before a density call is made.
CENTROMERE_MIN_WINDOWS = 5


def eprint(*args, **kwargs):
    print(*args, file=sys.stderr, **kwargs)


def parse_fai(path):
    """Return {sequence_name: length} from a samtools .fai index.

    A .fai line is: name<TAB>length<TAB>offset<TAB>linebases<TAB>linewidth
    """
    lengths = {}
    if not path:
        return lengths
    try:
        with open(path) as fh:
            for line in fh:
                line = line.rstrip("\n")
                if not line:
                    continue
                fields = line.split("\t")
                if len(fields) < 2:
                    continue
                name = fields[0]
                try:
                    lengths[name] = int(fields[1])
                except ValueError:
                    continue
    except FileNotFoundError:
        eprint(f"[telomere_table] WARNING: fai not found: {path}")
    return lengths


def parse_tidk_search(path):
    """Parse a `tidk search` TSV.

    tidk's CSV/TSV output has a header and the columns:
        id, window, forward_repeat_number, reverse_repeat_number, telomeric_repeat

    Older/newer versions vary in delimiter and exact column names, so we detect
    the header dynamically. Returns:
        windows[seq] -> list of (window_end, count)
    where count is forward+reverse repeat number for that window.
    """
    windows = defaultdict(list)
    if not path:
        return windows
    try:
        fh = open(path)
    except FileNotFoundError:
        eprint(f"[telomere_table] WARNING: tidk search not found: {path}")
        return windows

    with fh:
        header = None
        for raw in fh:
            line = raw.rstrip("\n")
            if not line:
                continue
            # tidk may emit comma- or tab-separated; pick whichever splits more.
            if "\t" in line and line.count("\t") >= line.count(","):
                fields = line.split("\t")
            else:
                fields = line.split(",")
            if header is None:
                # Heuristically detect a header row (non-numeric second column).
                lowered = [f.strip().lower() for f in fields]
                if any(h in lowered for h in ("id", "window", "telomeric_repeat",
                                              "forward_repeat_number")):
                    header = lowered
                    continue
                # No header — treat as positional and synthesize one.
                header = ["id", "window", "forward_repeat_number",
                          "reverse_repeat_number", "telomeric_repeat"]
                # fall through to parse this first data line below

            # Map columns by name where possible.
            def col(name, default_idx):
                if name in header:
                    idx = header.index(name)
                else:
                    idx = default_idx
                if idx < len(fields):
                    return fields[idx].strip()
                return ""

            seq = col("id", 0)
            if not seq:
                continue
            window_val = col("window", 1)
            fwd = col("forward_repeat_number", 2)
            rev = col("reverse_repeat_number", 3)

            try:
                window_end = int(float(window_val))
            except (ValueError, TypeError):
                window_end = 0
            try:
                fwd_n = int(float(fwd)) if fwd else 0
            except (ValueError, TypeError):
                fwd_n = 0
            try:
                rev_n = int(float(rev)) if rev else 0
            except (ValueError, TypeError):
                rev_n = 0

            windows[seq].append((window_end, fwd_n + rev_n))
    return windows


def parse_agp(path):
    """Parse an AGP file into {scaffold: [component_ids...]} for notes.

    Only used to annotate which contigs compose a scaffold. Robust to absence.
    """
    components = defaultdict(list)
    if not path:
        return components
    try:
        fh = open(path)
    except FileNotFoundError:
        return components
    with fh:
        for raw in fh:
            line = raw.rstrip("\n")
            if not line or line.startswith("#"):
                continue
            fields = line.split("\t")
            if len(fields) < 6:
                continue
            scaffold = fields[0]
            component_type = fields[4]
            # 'W' / 'D' / 'O' etc. are real sequence components; 'N'/'U' are gaps.
            if component_type.upper() not in ("N", "U"):
                component_id = fields[5]
                components[scaffold].append(component_id)
    return components


def build_rows(lengths, windows, agp_components):
    """Combine parsed inputs into per-sequence rows."""
    rows = []

    # Determine the universe of sequence names: prefer fai, union with tidk.
    seq_names = list(lengths.keys())
    for name in windows.keys():
        if name not in lengths:
            seq_names.append(name)

    for seq in seq_names:
        length = lengths.get(seq, 0)
        win = sorted(windows.get(seq, []), key=lambda x: x[0])

        total_repeats = sum(c for _, c in win)

        # Terminal window size for this sequence.
        if length > 0:
            terminal = min(int(length * TERMINAL_FRACTION), TERMINAL_MAX_BP)
            terminal = max(terminal, 1)
        else:
            # Without length info we cannot localize ends; fall back to first/last
            # few windows as a coarse proxy.
            terminal = 0

        five_prime = False
        three_prime = False
        interstitial_high = 0
        interstitial_total = 0

        for window_end, count in win:
            is_terminal_5 = False
            is_terminal_3 = False
            if length > 0 and terminal > 0:
                if window_end <= terminal:
                    is_terminal_5 = True
                if window_end >= (length - terminal):
                    is_terminal_3 = True

            if is_terminal_5 and count >= TELOMERE_MIN_REPEATS:
                five_prime = True
            if is_terminal_3 and count >= TELOMERE_MIN_REPEATS:
                three_prime = True

            if not is_terminal_5 and not is_terminal_3:
                interstitial_total += 1
                if count >= INTERSTITIAL_REPEAT_THRESHOLD:
                    interstitial_high += 1

        # Coarse fallback when length unknown: use first / last window.
        if length == 0 and win:
            if win[0][1] >= TELOMERE_MIN_REPEATS:
                five_prime = True
            if win[-1][1] >= TELOMERE_MIN_REPEATS:
                three_prime = True

        centromere_candidate = False
        if interstitial_total >= CENTROMERE_MIN_WINDOWS:
            density = interstitial_high / interstitial_total
            if density >= CENTROMERE_DENSITY_THRESHOLD:
                centromere_candidate = True

        notes_parts = []
        if five_prime and three_prime:
            notes_parts.append("both_ends_telomeric")
        elif five_prime or three_prime:
            notes_parts.append("one_end_telomeric")
        if centromere_candidate:
            notes_parts.append("interstitial_repeat_dense")
        if seq in agp_components:
            notes_parts.append(f"scaffold_of_{len(agp_components[seq])}_components")
        if length == 0:
            notes_parts.append("length_unknown")
        notes = ";".join(notes_parts) if notes_parts else "."

        rows.append({
            "sequence": seq,
            "length": length,
            "telomere_5prime": bool(five_prime),
            "telomere_3prime": bool(three_prime),
            "telomere_repeat_count": int(total_repeats),
            "centromere_candidate": bool(centromere_candidate),
            "notes": notes,
        })

    # Stable ordering: longest sequences first, then by name.
    rows.sort(key=lambda r: (-r["length"], r["sequence"]))
    return rows


def write_tsv(rows, path):
    columns = ["sequence", "length", "telomere_5prime", "telomere_3prime",
               "telomere_repeat_count", "centromere_candidate", "notes"]
    with open(path, "w") as fh:
        fh.write("\t".join(columns) + "\n")
        for r in rows:
            fh.write("\t".join(str(r[c]) for c in columns) + "\n")


def write_json(rows, path, meta):
    payload = {
        "schema_version": "1.0",
        "tool": "telomere_table.py",
        "metadata": meta,
        "sequences": rows,
        "summary": {
            "n_sequences": len(rows),
            "n_t2t_both_ends": sum(
                1 for r in rows
                if r["telomere_5prime"] and r["telomere_3prime"]
            ),
            "n_one_end_telomeric": sum(
                1 for r in rows
                if r["telomere_5prime"] ^ r["telomere_3prime"]
            ),
            "n_centromere_candidates": sum(
                1 for r in rows if r["centromere_candidate"]
            ),
        },
    }
    with open(path, "w") as fh:
        json.dump(payload, fh, indent=2)
        fh.write("\n")


def main(argv=None):
    parser = argparse.ArgumentParser(
        description="Build a per-sequence telomere/centromere candidate table "
                    "from tidk search output."
    )
    parser.add_argument("--tidk-search", dest="tidk_search", default=None,
                        help="tidk search TSV/CSV output (per-window repeats).")
    parser.add_argument("--fai", dest="fai", default=None,
                        help="samtools .fai index for sequence lengths.")
    parser.add_argument("--agp", dest="agp", default=None,
                        help="Optional scaffolding AGP file for annotation.")
    parser.add_argument("--out-tsv", dest="out_tsv", required=True,
                        help="Output TSV path.")
    parser.add_argument("--out-json", dest="out_json", required=True,
                        help="Output JSON path.")
    args = parser.parse_args(argv)

    # pandas is a declared dependency of the container; import defensively so the
    # script still produces output even if pandas is unavailable.
    try:
        import pandas  # noqa: F401  (imported to satisfy the contract / availability)
        _have_pandas = True
    except Exception:  # pragma: no cover
        _have_pandas = False

    lengths = parse_fai(args.fai)
    windows = parse_tidk_search(args.tidk_search)
    agp_components = parse_agp(args.agp)

    rows = build_rows(lengths, windows, agp_components)

    meta = {
        "tidk_search": args.tidk_search or "",
        "fai": args.fai or "",
        "agp": args.agp or "",
        "pandas_available": _have_pandas,
        "heuristics": {
            "terminal_fraction": TERMINAL_FRACTION,
            "terminal_max_bp": TERMINAL_MAX_BP,
            "telomere_min_repeats": TELOMERE_MIN_REPEATS,
            "interstitial_repeat_threshold": INTERSTITIAL_REPEAT_THRESHOLD,
            "centromere_density_threshold": CENTROMERE_DENSITY_THRESHOLD,
            "centromere_min_windows": CENTROMERE_MIN_WINDOWS,
        },
    }

    write_tsv(rows, args.out_tsv)
    write_json(rows, args.out_json, meta)

    eprint(f"[telomere_table] wrote {len(rows)} sequence rows -> "
           f"{args.out_tsv}, {args.out_json}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
