"""
Annualised APY calculation from funding-rate spreads.

Adapted from the arbitrage opportunity logic in Delta Hedge's
``backend/app/routers/opportunities.py``.

Converts a basis-point spread between two venues into an annualised
percentage yield (APY) based on the funding interval.
"""

from __future__ import annotations


def annualized_apy(spread_bps: float, interval_hours: float = 8) -> float:
    """Convert a funding-rate spread to an annualised APY.

    The formula assumes the spread is captured every ``interval_hours``
    and compounds linearly over a year:

    .. code-block:: text

        APY (%) = |spread_bps| × (365 / (interval_hours / 24)) / 10000 × 100

    Parameters
    ----------
    spread_bps : float
        Spread between two venues in basis points (e.g. ``10`` for 10 bps).
    interval_hours : float, default ``8``
        Number of hours between funding events (e.g. 8 for Binance,
        1 for Hyperliquid).

    Returns
    -------
    float
        Annualised percentage yield (e.g. ``109.5`` for 109.5 % APY).

    Examples
    --------
    >>> annualized_apy(10, 8)
    109.5
    >>> annualized_apy(0, 8)
    0.0
    """
    funding_periods = 365.0 / (interval_hours / 24.0)
    return abs(spread_bps) * funding_periods / 10000.0 * 100.0
