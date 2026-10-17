"""Slow, obvious whole-number helpers for the Zone 4 and 5 checkers.

Everything here is written from the definitions (divisors by trying every number, multiples by counting
up, a prime as "exactly two divisors") and shares nothing with scripts/core/math_util.gd. Speed does
not matter: the numbers are small.
"""
from __future__ import annotations


def divisors(n: int) -> list[int]:
    """Every whole number from 1 to n that goes into n with nothing left over."""
    return [d for d in range(1, n + 1) if n % d == 0]


def is_prime(n: int) -> bool:
    return n >= 2 and len(divisors(n)) == 2


def smallest_divisor_above_one(n: int) -> int:
    return next(d for d in range(2, n + 1) if n % d == 0)


def is_square(n: int) -> bool:
    return any(root * root == n for root in range(1, n + 1))


def count_up(step: int, count: int) -> list[int]:
    """step, step + step, ... (count of them), by adding."""
    found: list[int] = []
    at = 0
    for _ in range(count):
        at += step
        found.append(at)
    return found


def product(a: int, b: int) -> int:
    """a groups of b, by adding b to itself a times."""
    total = 0
    for _ in range(a):
        total += b
    return total


def first_shared_multiple(a: int, b: int) -> int:
    """The first number that is in both lists of multiples."""
    of_b = set(count_up(b, a))
    return next(value for value in count_up(a, b) if value in of_b)


def greatest_shared_divisor(a: int, b: int) -> int:
    return max(d for d in divisors(a) if b % d == 0)


def pair_count(n: int) -> int:
    """Pairs of whole numbers that multiply to n, with 3 x 4 and 4 x 3 counted once."""
    return sum(1 for a in range(1, n + 1) for b in range(a, n + 1) if a * b == n)


def share_equally(total: int, carts: int) -> int | None:
    """Gems each cart gets when `total` gems are dealt out one at a time, or None if the carts
    do not all end up with the same number."""
    hands = [0] * carts
    for gem in range(total):
        hands[gem % carts] += 1
    return hands[0] if len(set(hands)) == 1 else None


def array_picture(rows: int, cols: int, outline: bool = False) -> dict:
    picture: dict = {"type": "array", "rows": rows, "cols": cols}
    if outline:
        picture["outline_rows"] = True
    return picture


def number_line(low: int, high: int, every: int, markers: list[int] | None = None, jumps: list[tuple[int, int]] | None = None) -> dict:
    line: dict = {"type": "number_line", "min": low, "max": high, "labeled_every": every, "markers": list(markers or []), "blanks": []}
    if jumps is not None:
        line["jumps"] = [{"from": a, "to": b} for a, b in jumps]
    return line


def hops(groups: int, size: int, markers: list[int] | None = None) -> dict:
    """A line from 0 to groups x size with one hop of `size` per group."""
    return number_line(0, groups * size, size, markers, [(i * size, (i + 1) * size) for i in range(groups)])
