#!/usr/bin/env python3
"""Compare a freshly generated results.json against the deposited one.

usage: compare_results.py DEPOSITED.json FRESH.json [--tol ABS] [--ignore PATH]...

Walks both JSON trees leaf by leaf and compares the parsed values, never the
file hashes: results.json carries the run date (meta.date_run), so its bytes
change with the day of the run even when every number is identical.

  --tol ABS      absolute numeric tolerance, default 0 (exact equality of the
                 parsed numbers; 3 equals 3.0).
  --ignore PATH  dotted path to skip, repeatable; list items are written
                 name[i]. meta.date_run is always ignored. For a run on a
                 different machine, the software-version strings may also
                 differ: --ignore meta.R_version
                 --ignore meta.packages.metafor --ignore meta.packages.jsonlite

Comparison rules: dictionaries must have the same keys; lists the same length;
booleans must be booleans and equal; numbers are equal within the tolerance;
strings must match exactly; anything else (null, mixed types) must match in
type and value. The leaf counts are taken from the files, nothing is
hard-coded. Nothing is written to disk.

Exit codes: 0 = no differences outside the ignored paths, 1 = at least one
difference, 2 = usage error, unreadable file or invalid JSON.
"""
import json
import sys

ALWAYS_IGNORED = {"meta.date_run"}
MAX_SHOWN = 50


def walk(old, new, path, tol, ignored, st):
    if path in ignored:
        st["ignored_seen"].add(path)
        return
    if isinstance(old, dict) and isinstance(new, dict):
        for k in old:
            sub = k if not path else path + "." + k
            if k in new:
                walk(old[k], new[k], sub, tol, ignored, st)
            elif sub not in ignored:
                st["diffs"].append((sub, "key missing in fresh output"))
        for k in new:
            if k not in old:
                sub = k if not path else path + "." + k
                if sub not in ignored:
                    st["diffs"].append((sub, "key only in fresh output"))
        return
    if isinstance(old, list) and isinstance(new, list):
        if len(old) != len(new):
            st["diffs"].append((path, "list length %d -> %d" % (len(old), len(new))))
            return
        for i, (a, b) in enumerate(zip(old, new)):
            walk(a, b, "%s[%d]" % (path, i), tol, ignored, st)
        return
    if isinstance(old, (dict, list)) or isinstance(new, (dict, list)):
        st["diffs"].append((path, "structure differs: %s vs %s"
                            % (type(old).__name__, type(new).__name__)))
        return
    # Scalar leaves. bool is a subclass of int, so test it first.
    if isinstance(old, bool) or isinstance(new, bool):
        st["other"] += 1
        if not (isinstance(old, bool) and isinstance(new, bool) and old == new):
            st["diffs"].append((path, "%r -> %r" % (old, new)))
        return
    if isinstance(old, (int, float)) and isinstance(new, (int, float)):
        st["numeric"] += 1
        if abs(old - new) > tol:          # tol = 0 means exact equality; 3 == 3.0
            st["diffs"].append((path, "numeric %r -> %r" % (old, new)))
        return
    if isinstance(old, str) and isinstance(new, str):
        st["string"] += 1
        if old != new:
            st["diffs"].append((path, "string differs"))
        return
    st["other"] += 1                      # null, or mixed types
    if old != new or type(old) is not type(new):
        st["diffs"].append((path, "%r -> %r" % (old, new)))


def main(argv):
    args, ignored, tol, i = [], set(ALWAYS_IGNORED), 0.0, 0
    try:
        while i < len(argv):
            a = argv[i]
            if a == "--tol" and i + 1 < len(argv):
                tol = float(argv[i + 1])
                i += 2
            elif a == "--ignore" and i + 1 < len(argv):
                ignored.add(argv[i + 1])
                i += 2
            elif a.startswith("-"):
                print("unknown option: " + a, file=sys.stderr)
                return 2
            else:
                args.append(a)
                i += 1
    except ValueError as exc:
        print("ERROR: bad option value: %s" % exc, file=sys.stderr)
        return 2
    if len(args) != 2:
        print(__doc__, file=sys.stderr)
        return 2
    try:
        with open(args[0], encoding="utf-8") as fh:
            old = json.load(fh)
        with open(args[1], encoding="utf-8") as fh:
            new = json.load(fh)
    except (OSError, ValueError) as exc:
        print("ERROR: %s" % exc, file=sys.stderr)
        return 2
    st = {"numeric": 0, "string": 0, "other": 0, "diffs": [], "ignored_seen": set()}
    walk(old, new, "", tol, ignored, st)
    print("deposited: " + args[0])
    print("fresh    : " + args[1])
    print("tolerance: %g (absolute; 0 = exact)" % tol)
    print("ignored  : " + ", ".join(sorted(ignored)))
    print("leaves compared: %d numeric, %d string, %d bool/null"
          % (st["numeric"], st["string"], st["other"]))
    print("differences: %d" % len(st["diffs"]))
    for p, d in st["diffs"][:MAX_SHOWN]:
        print("  DIFF %s : %s" % (p, d))
    if len(st["diffs"]) > MAX_SHOWN:
        print("  ... %d more" % (len(st["diffs"]) - MAX_SHOWN))
    ok = not st["diffs"]
    print("RESULT: " + ("PASS" if ok else "FAIL"))
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
