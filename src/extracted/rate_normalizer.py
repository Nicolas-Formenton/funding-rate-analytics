"""
Funding rate normalization utilities.

Adapted from Delta Hedge's ``_extract_rate()`` function in
``backend/app/services/data_aggregator.py``.

Extracts raw funding rates from API response payloads and converts them to
annualized percentages using venue-specific formulas.
"""

from __future__ import annotations

from typing import Any, Optional


def extract_rate(payload: Optional[dict[str, Any]]) -> Optional[float]:
    """Extract a raw funding rate from an exchange API response payload.

    Tries common JSON key names (``fundingRate``, ``funding_rate``, ``rate``)
    and returns the first valid float found.

    Parameters
    ----------
    payload : dict or None
        The API response dictionary, or ``None`` if the request failed.

    Returns
    -------
    float or None
        The raw funding rate as a float, or ``None`` if no valid rate was found.
    """
    if not payload:
        return None
    for key in ("fundingRate", "funding_rate", "rate"):
        v = payload.get(key)
        if v is None:
            continue
        try:
            return float(v)
        except (ValueError, TypeError):
            continue
    return None


def normalize(
    rate: float,
    venue: str,
    interval_hours: float = 8,
) -> float:
    """Convert a raw funding rate to an annualized percentage.

    Each venue charges (or pays) funding at a different cadence.  This
    function annualises the raw rate so that rates from different exchanges
    are comparable.

    **Supported venues and formulas** (``per-period count = 24 / interval_hours``):

    | Venue         | Raw rate meaning       | Annualization formula          |
    |---------------|------------------------|--------------------------------|
    | ``binance``   | Decimal per period     | ``rate * per-periods * 365 * 100`` |
    | ``hyperliquid`` | Decimal per period   | ``rate * per-periods * 365 * 100`` |
    | ``deribit``   | Interest % per period  | ``rate / 100 * per-periods * 365 * 100`` |

    For Binance and Hyperliquid the raw rate is already a decimal (e.g.
    ``0.0001``).  Deribit returns an interest percentage (e.g. ``0.01`` for
    0.01 %), so it is first divided by 100.

    Parameters
    ----------
    rate : float
        Raw funding rate from the exchange API.
    venue : str
        Exchange name (case-insensitive).  One of ``"binance"``,
        ``"hyperliquid"``, or ``"deribit"``.
    interval_hours : float, default ``8``
        Hours between funding events for this venue.  Binance and Deribit
        use 8 h by default; Hyperliquid uses 1 h.

    Returns
    -------
    float
        Annualised funding rate as a percentage (e.g. ``10.95`` for 10.95 %).
    """
    periods_per_day = 24.0 / interval_hours
    venue_key = venue.strip().lower()

    if venue_key == "deribit":
        # Deribit returns an interest percentage; convert to decimal first.
        annualized = (rate / 100.0) * periods_per_day * 365.0 * 100.0
    else:
        # Binance / Hyperliquid / generic: raw rate is already a decimal.
        annualized = rate * periods_per_day * 365.0 * 100.0

    return annualized
