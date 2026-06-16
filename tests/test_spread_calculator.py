"""Tests for src/extracted/spread_calculator.py."""

import pytest

from src.extracted.spread_calculator import (
    calculate_spread_bps,
    identify_arb_venue_pair,
)


class TestCalculateSpreadBps:
    def test_positive_spread(self) -> None:
        # 10.95 % - 5.0 % = 5.95 % → 595 bps
        assert calculate_spread_bps(10.95, 5.0) == pytest.approx(595.0)

    def test_negative_spread_absolute(self) -> None:
        # 5.0 % - 10.95 % = -5.95 % → abs → 595 bps
        assert calculate_spread_bps(5.0, 10.95) == pytest.approx(595.0)

    def test_zero_spread(self) -> None:
        assert calculate_spread_bps(7.5, 7.5) == 0.0


class TestIdentifyArbVenuePair:
    def test_selects_largest_spread_pair(self) -> None:
        rates = {
            "binance": 10.95,
            "hyperliquid": 8.76,
            "deribit": 2.0,
        }
        a, b, spread = identify_arb_venue_pair(rates)
        # Binance (10.95) vs Deribit (2.0) → 8.95 % → 895 bps is the largest
        assert {a, b} == {"binance", "deribit"}
        assert spread == pytest.approx(895.0)

    def test_two_venues_only(self) -> None:
        rates = {"exchange_a": 5.0, "exchange_b": 10.0}
        a, b, spread = identify_arb_venue_pair(rates)
        assert {a, b} == {"exchange_a", "exchange_b"}
        assert spread == pytest.approx(500.0)

    def test_raises_on_single_venue(self) -> None:
        with pytest.raises(ValueError, match="At least two venues"):
            identify_arb_venue_pair({"only": 1.0})
