"""
Cross-venue funding spread calculation utilities.

Adapted from Delta Hedge's ``funding_spread()`` method in
``backend/app/services/data_aggregator.py``.

Provides functions to compute the basis-point spread between two funding
rates and to identify the venue pair with the largest arbitrage opportunity.
"""

from __future__ import annotations


def calculate_spread_bps(rate_a: float, rate_b: float) -> float:
    """Return the absolute difference between two rates in basis points.

    1 basis point = 0.01 % → ``|rate_a - rate_b| * 100`` when both rates
    are already expressed as percentages.

    Parameters
    ----------
    rate_a : float
        First funding rate (annualised percentage, e.g. ``10.95``).
    rate_b : float
        Second funding rate (annualised percentage).

    Returns
    -------
    float
        Absolute spread in basis points.
    """
    return abs(rate_a - rate_b) * 100.0


def identify_arb_venue_pair(venue_rates: dict[str, float]) -> tuple[str, str, float]:
    """Find the two venues with the largest funding-rate spread.

    Examines every pair of venues in ``venue_rates`` and returns the pair
    whose annualised rates differ by the greatest absolute amount.

    Parameters
    ----------
    venue_rates : dict of str → float
        Mapping of venue name to annualised funding rate (percentage).
        At least two entries are required.

    Returns
    -------
    tuple of (str, str, float)
        ``(venue_a, venue_b, spread_bps)`` where ``venue_a`` and ``venue_b``
        are the two venue names and ``spread_bps`` is the absolute spread in
        basis points.

    Raises
    ------
    ValueError
        If fewer than two venues are provided.
    """
    if len(venue_rates) < 2:
        raise ValueError("At least two venues are required to identify an arbitrage pair.")

    venues = list(venue_rates.items())
    best_pair: tuple[str, str] | None = None
    best_spread_bps = -1.0

    for i in range(len(venues)):
        for j in range(i + 1, len(venues)):
            name_a, rate_a = venues[i]
            name_b, rate_b = venues[j]
            spread_bps = calculate_spread_bps(rate_a, rate_b)
            if spread_bps > best_spread_bps:
                best_spread_bps = spread_bps
                best_pair = (name_a, name_b)

    assert best_pair is not None  # validated by the len check above
    return (best_pair[0], best_pair[1], best_spread_bps)
