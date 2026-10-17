"""pytest for tools/crosscheck/rare_numbers.py: known values by hand, and the shipped JSON list."""
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import rare_numbers  # noqa: E402


def test_the_sieve_finds_the_168_primes_below_1000_and_1229_below_10000():
    primes = rare_numbers.sieve(10_000)
    assert sum(primes[:1000]) == 168
    assert sum(primes[:10_001]) == 1229


def test_the_mersenne_primes_up_to_ten_thousand():
    assert rare_numbers.mersenne_primes(10_000) == [3, 7, 31, 127, 8191]
    assert rare_numbers.mersenne_primes(1_000_000)[-1] == 524287  # 2^19 - 1


def test_the_shipped_mersenne_list_matches():
    shipped = json.loads(rare_numbers.RARE_JSON.read_text())
    assert shipped["mersenne_primes"] == rare_numbers.mersenne_primes(10_000)
    assert shipped["schema_version"] == 1


def test_known_numbers_get_the_right_gem():
    t = rare_numbers.table()
    assert t[1] == "square_gem"  # 1 is a perfect square, not a prime
    assert t[2] == "prime_gem"  # 2 has no prime two away (0 is not prime, 4 is not prime)
    assert t[3] == "mersenne_gem"  # also a twin prime: the rarer gem wins
    assert t[5] == "twin_gem" and t[7] == "mersenne_gem" and t[11] == "twin_gem" and t[13] == "twin_gem"
    assert t[23] == "prime_gem" and t[29] == "twin_gem" and t[31] == "mersenne_gem"
    assert t[4] == "square_gem" and t[9] == "square_gem" and t[10_000] == "square_gem"
    assert t[6] == "" and t[12] == "" and t[8191] == "mersenne_gem"


def test_every_gem_follows_the_written_definitions():
    t = rare_numbers.table()
    primes = rare_numbers.sieve(10_000)
    for n in range(1, 10_001):
        gem = t[n]
        is_square = round(n ** 0.5) ** 2 == n
        if gem in ("mersenne_gem", "twin_gem", "prime_gem"):
            assert primes[n]
        else:
            assert not primes[n]
        assert (gem == "square_gem") == (is_square and not primes[n])
        if gem == "twin_gem":
            assert primes[n - 2] or primes[n + 2]
        if gem == "prime_gem":
            assert not (n >= 3 and primes[n - 2]) and not primes[n + 2]


def test_write_makes_a_fixture_with_one_entry_per_number(tmp_path, monkeypatch):
    monkeypatch.setattr(rare_numbers, "OUT", tmp_path / "fixture.json")
    assert rare_numbers.main(["--write"]) == 0
    data = json.loads((tmp_path / "fixture.json").read_text())
    assert data["limit"] == 10_000 and len(data["gems"]) == 10_000 and data["gems"][2] == "mersenne_gem"
