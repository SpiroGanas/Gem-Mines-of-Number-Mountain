#!/usr/bin/env python3
"""Independent list of which rare gem every number from 1 to 10,000 earns (Sprint 15).

The game decides this in GDScript (RewardsRules.gem_for_value, using MathUtil). This module shares no
code with it: a sieve of Eratosthenes, the definitions written out, and the Mersenne primes found
by testing 2^p - 1. The GDScript test compares every number with the fixture this writes:

    python tools/crosscheck/rare_numbers.py --write     # tests/rewards/fixtures/rare_gems.json

Rules (docs/phases/phase-2-version-1-0.md, "Rare gems from rare numbers"), highest first:
    mersenne_gem   a Mersenne prime 2^p - 1 (3, 7, 31, 127, 8191)
    twin_gem       a prime whose neighbour two away (n - 2 or n + 2) is also prime (drops as a pair)
    prime_gem      any other prime
    square_gem     a perfect square (1, 4, 9, ...)
    ""             anything else: the zone's common gem (decided by the game)
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

LIMIT = 10_000
OUT = Path(__file__).resolve().parents[2] / "tests" / "rewards" / "fixtures" / "rare_gems.json"
RARE_JSON = Path(__file__).resolve().parents[2] / "curriculum" / "rare_numbers.json"


def sieve(limit: int) -> list[bool]:
    """is_prime[n] for 0..limit."""
    flags = [True] * (limit + 3)
    flags[0] = flags[1] = False
    i = 2
    while i * i <= limit + 2:
        if flags[i]:
            for multiple in range(i * i, limit + 3, i):
                flags[multiple] = False
        i += 1
    return flags


def mersenne_primes(limit: int) -> list[int]:
    primes = sieve(limit)
    found = []
    exponent = 2
    while (1 << exponent) - 1 <= limit:
        value = (1 << exponent) - 1
        if primes[exponent] and primes[value]:
            found.append(value)
        exponent += 1
    return found


def gem_for(n: int, primes: list[bool], mersenne: set[int]) -> str:
    if n in mersenne:
        return "mersenne_gem"
    if primes[n]:
        if (n >= 3 and primes[n - 2]) or primes[n + 2]:
            return "twin_gem"
        return "prime_gem"
    root = int(n ** 0.5)
    while root * root > n:
        root -= 1
    while (root + 1) * (root + 1) <= n:
        root += 1
    if root * root == n:
        return "square_gem"
    return ""


def table(limit: int = LIMIT) -> dict[int, str]:
    primes = sieve(limit)
    mersenne = set(mersenne_primes(limit))
    return {n: gem_for(n, primes, mersenne) for n in range(1, limit + 1)}


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("--write", action="store_true", help=f"write {OUT}")
    args = ap.parse_args(argv)
    result = table()
    if args.write:
        OUT.parent.mkdir(parents=True, exist_ok=True)
        OUT.write_text(json.dumps({"limit": LIMIT, "gems": [result[n] for n in range(1, LIMIT + 1)]}, separators=(",", ":")) + "\n", encoding="utf-8")
        print(f"wrote {OUT}")
    counts: dict[str, int] = {}
    for gem in result.values():
        counts[gem or "(common)"] = counts.get(gem or "(common)", 0) + 1
    print(counts)
    return 0


if __name__ == "__main__":
    sys.exit(main())
