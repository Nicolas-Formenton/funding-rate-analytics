"""Tests for src/extracted/apy_formula.py."""

import pytest

from src.extracted.apy_formula import annualized_apy


class TestAnnualizedApy:
    def test_basic_apy(self) -> None:
        """10 bps spread at 8 h funding → 109.5 % APY.

        Formula: |10| * (365 / (8/24)) / 10000 * 100
               = 10 * 1095 / 10000 * 100
               = 109.5
        """
        result = annualized_apy(10.0, 8)
        assert result == pytest.approx(109.5)

    def test_zero_spread(self) -> None:
        assert annualized_apy(0.0, 8) == 0.0

    def test_negative_spread_uses_absolute(self) -> None:
        """Negative spread should be treated the same as positive."""
        result = annualized_apy(-10.0, 8)
        assert result == pytest.approx(109.5)

    def test_hyperliquid_interval(self) -> None:
        """5 bps spread at 1 h funding.

        |5| * (365 / (1/24)) / 10000 * 100
        = 5 * 8760 / 10000 * 100
        = 438.0
        """
        result = annualized_apy(5.0, 1)
        assert result == pytest.approx(438.0)
