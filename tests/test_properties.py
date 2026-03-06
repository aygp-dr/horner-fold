#!/usr/bin/env python3
"""Property-based tests for Horner encode/decode using Hypothesis."""
# /// script
# requires-python = ">=3.10"
# dependencies = ["hypothesis"]
# ///

from hypothesis import given, assume, settings
from hypothesis import strategies as st


# --- Horner encode/decode ---

def horner_encode(values: list[int], base: int) -> int:
    """Fold a sequence of values into a single integer via Horner's method."""
    acc = 0
    for v in values:
        acc = acc * base + v
    return acc


def horner_decode(n: int, base: int) -> list[int]:
    """Unfold an integer into a sequence of values (inverse of horner_encode)."""
    if n == 0:
        return []
    acc = []
    while n > 0:
        acc.append(n % base)
        n //= base
    return list(reversed(acc))


def horner_encode_string(s: str, base: int) -> int:
    return horner_encode([ord(c) for c in s], base)


def horner_decode_string(n: int, base: int) -> str:
    return "".join(chr(v) for v in horner_decode(n, base))


# --- Strategies ---

# Tuple of ints in [0, base) with first element > 0 (no leading zeros)
def tuple_with_base(max_rank=8, max_base=100):
    return st.integers(min_value=2, max_value=max_base).flatmap(
        lambda base: st.tuples(
            st.just(base),
            st.lists(
                st.integers(min_value=0, max_value=base - 1),
                min_size=1, max_size=max_rank
            )
        )
    )


def nonzero_leading_tuple(max_rank=8, max_base=100):
    """Tuple with first element > 0 (needed for roundtrip)."""
    return st.integers(min_value=2, max_value=max_base).flatmap(
        lambda base: st.tuples(
            st.just(base),
            st.integers(min_value=1, max_value=base - 1),
            st.lists(
                st.integers(min_value=0, max_value=base - 1),
                min_size=0, max_size=max_rank - 1
            )
        ).map(lambda t: (t[0], [t[1]] + t[2]))
    )


ascii_strings = st.text(
    st.characters(min_codepoint=1, max_codepoint=127),
    min_size=1, max_size=20
)


# --- Property Tests ---

class TestRoundtrip:
    """Encode then decode should return the original."""

    @given(data=nonzero_leading_tuple())
    def test_tuple_roundtrip(self, data):
        base, values = data
        encoded = horner_encode(values, base)
        decoded = horner_decode(encoded, base)
        assert decoded == values

    @given(s=ascii_strings, base=st.integers(min_value=128, max_value=256))
    def test_string_roundtrip(self, s, base):
        encoded = horner_encode_string(s, base)
        decoded = horner_decode_string(encoded, base)
        assert decoded == s


class TestPolynomialEquivalence:
    """Horner evaluation should match naive polynomial expansion."""

    @given(data=tuple_with_base(max_rank=6, max_base=50))
    def test_matches_naive(self, data):
        base, coeffs = data
        horner_result = horner_encode(coeffs, base)
        naive_result = sum(
            c * base ** (len(coeffs) - 1 - i) for i, c in enumerate(coeffs)
        )
        assert horner_result == naive_result


class TestAlgebraicProperties:
    """Structural properties of the Horner encoding."""

    @given(x=st.integers(min_value=0, max_value=99),
           base=st.integers(min_value=100, max_value=200))
    def test_single_element_identity(self, x, base):
        """Encoding a single element returns itself."""
        assert horner_encode([x], base) == x

    @given(data=tuple_with_base())
    def test_leading_zero_absorption(self, data):
        """Prepending a zero doesn't change the encoding."""
        base, values = data
        assert horner_encode([0] + values, base) == horner_encode(values, base)

    @given(data=tuple_with_base(max_rank=4, max_base=30))
    def test_concatenation_shift(self, data):
        """encode(a ++ b) == encode(a) * base^|b| + encode(b)."""
        base, values = data
        assume(len(values) >= 2)
        split = len(values) // 2
        a, b = values[:split], values[split:]
        assert horner_encode(values, base) == (
            horner_encode(a, base) * base ** len(b) + horner_encode(b, base)
        )

    @given(data=tuple_with_base())
    def test_encoding_non_negative(self, data):
        """Encoding is always non-negative."""
        base, values = data
        assert horner_encode(values, base) >= 0


class TestMonotonicity:
    """Ordering properties."""

    @given(
        base=st.integers(min_value=3, max_value=50),
        prefix=st.lists(st.integers(min_value=0, max_value=10), min_size=0, max_size=3),
        a=st.integers(min_value=0, max_value=48),
    )
    def test_monotone_last_element(self, base, prefix, a):
        """Larger last element means larger encoding."""
        assume(a + 1 < base)
        assume(all(v < base for v in prefix))
        b = a + 1
        assert (
            horner_encode(prefix + [a], base)
            < horner_encode(prefix + [b], base)
        )


class TestKnownValues:
    """Concrete test cases from the org file."""

    def test_base_10_digits(self):
        assert horner_encode([1, 2, 3], 10) == 123

    def test_base_6_tuple(self):
        assert horner_encode([3, 1, 4, 1, 5], 6) == 4259

    def test_horner_string(self):
        s = "horner!"
        base = 128
        n = horner_encode_string(s, base)
        assert n > 0
        assert horner_decode_string(n, base) == s

    def test_decode_tuple_known(self):
        assert horner_decode(123, 10) == [1, 2, 3]
