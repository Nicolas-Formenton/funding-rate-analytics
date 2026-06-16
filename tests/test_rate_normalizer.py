"""Tests for src/extracted/rate_normalizer.py."""

import pytest

from src.extracted.rate_normalizer import extract_rate, normalize


class TestExtractRate:
    """Tests for the ``extract_rate()`` payload-parsing function."""

    def test_returns_rate_for_fundingRate_key(self) -> None:
        payload = {"fundingRate": "0.0001", "symbol": "BTCUSDT"}
        assert extract_rate(payload) == 0.0001

    def test_returns_rate_for_funding_rate_key(self) -> None:
        payload = {"funding_rate": 0.0002, "symbol": "ETHUSDT"}
        assert extract_rate(payload) == 0.0002

    def test_returns_rate_for_rate_key(self) -> None:
        payload = {"rate": 0.0003}
        assert extract_rate(payload) == 0.0003

    def test_returns_none_for_empty_payload(self) -> None:
        assert extract_rate({}) is None

    def test_returns_none_for_none_payload(self) -> None:
        assert extract_rate(None) is None

    def test_returns_none_when_no_known_key_exists(self) -> None:
        payload = {"price": "50000"}
        assert extract_rate(payload) is None

    def test_returns_first_valid_rate_by_key_priority(self) -> None:
        payload = {"fundingRate": "0.001", "funding_rate": "0.002"}
        assert extract_rate(payload) == 0.001


class TestNormalize:
    """Tests for the ``normalize()`` annualised-percentage function."""

    # --- Binance (default 8 h interval) ---
    # 0.0001 * (24/8) * 365 * 100 = 0.0001 * 3 * 365 * 100 = 10.95

    def test_binance_positive_rate(self) -> None:
        result = normalize(0.0001, "binance", 8)
        assert result == pytest.approx(10.95)

    def test_binance_negative_rate(self) -> None:
        result = normalize(-0.0002, "binance", 8)
        assert result == pytest.approx(-21.9)

    def test_binance_zero_rate(self) -> None:
        assert normalize(0.0, "binance", 8) == 0.0

    # --- Hyperliquid (default 1 h interval) ---
    # 0.00001 * (24/1) * 365 * 100 = 0.00001 * 24 * 365 * 100 = 8.76

    def test_hyperliquid_hourly(self) -> None:
        result = normalize(0.00001, "hyperliquid", 1)
        assert result == pytest.approx(8.76)

    # --- Deribit (internal % per period) ---
    # 0.01 % / 100 * (24/8) * 365 * 100 = 0.0001 * 3 * 365 * 100 = 10.95

    def test_deribit_interest_rate(self) -> None:
        result = normalize(0.01, "deribit", 8)  # 0.01 % raw
        assert result == pytest.approx(10.95)

    # --- Case insensitivity ---

    def test_venue_case_insensitive(self) -> None:
        assert normalize(0.0001, "Binance", 8) == pytest.approx(10.95)
        assert normalize(0.0001, "BINANCE", 8) == pytest.approx(10.95)
