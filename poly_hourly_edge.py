#!/usr/bin/env python3
"""TRUE-edge test on REAL Polymarket prices for the HOURLY (and 4h if found)
   BTC Up/Down series. Mirrors poly_5m_edge.py but for longer horizons.

Enumerates the recurring series via gamma /events?series_id=, reads each market's
Up token + settlement (outcomePrices) + close (endDate), pulls CLOB price history,
and for each lookback T computes the REAL favorite edge = win_rate - avg_price_paid.
"""

import json
import time
import statistics as st
import datetime as dt
from urllib.request import urlopen, Request

GAMMA = "https://gamma-api.polymarket.com"
CLOB = "https://clob.polymarket.com"
HOURLY_SERIES = "10114"          # btc-up-or-down-hourly
SAMPLE = 350                     # markets per series
TOL = 95                         # match a 1-min history point within +-TOL sec


def get(url, want_nonempty=False):
    last = None
    for i in range(10):
        try:
            req = Request(url, headers={"User-Agent": "Mozilla/5.0"})
            d = json.loads(urlopen(req, timeout=30).read())
            if want_nonempty and isinstance(d, list) and not d:
                last = "empty"; time.sleep(0.5 * (i + 1)); continue
            return d, None
        except Exception as e:
            last = str(e); time.sleep(0.6 * (i + 1))
    return None, last


def epoch(iso):
    return int(dt.datetime.fromisoformat(iso.replace("Z", "+00:00")).timestamp())


def collect_series(series_id, want):
    """Page closed events in a series; return list of market dicts."""
    out = []
    offset = 0
    while len(out) < want:
        ev, err = get(f"{GAMMA}/events?series_id={series_id}&closed=true"
                      f"&limit=100&offset={offset}&order=endDate&ascending=false")
        if err or not isinstance(ev, list) or not ev:
            break
        for e in ev:
            for m in (e.get("markets") or []):
                out.append(m)
        offset += 100
        time.sleep(0.05)
    return out[:want]


def price_at(hist, target):
    best = None
    for p in hist:
        d = abs(p["t"] - target)
        if d <= TOL and (best is None or d < best[0]):
            best = (d, p["p"])
    return best[1] if best else None


def test_series(name, series_id, window, lookbacks):
    print(f"\n#### {name} (series {series_id}, window {window}s) ####")
    mkts = collect_series(series_id, SAMPLE)
    print(f"  collected {len(mkts)} markets")

    fav_win = {t: 0 for t in lookbacks}
    fav_px = {t: [] for t in lookbacks}
    n = {t: 0 for t in lookbacks}
    used = 0; skip = 0

    for i, m in enumerate(mkts):
        try:
            toks = json.loads(m.get("clobTokenIds") or "[]")
            op = json.loads(m.get("outcomePrices") or "[]")
            up_tok = toks[0]
            up_won = float(op[0]) > 0.5            # outcomePrices ["1","0"]=>Up won
            close = epoch(m.get("endDate"))
        except (ValueError, IndexError, TypeError):
            skip += 1; continue
        ph, _ = get(f"{CLOB}/prices-history?market={up_tok}"
                    f"&startTs={close-window-120}&endTs={close+180}&fidelity=1")
        hist = ph.get("history", []) if isinstance(ph, dict) else []
        if len(hist) < 4:
            skip += 1
        else:
            used += 1
            for t in lookbacks:
                p = price_at(hist, close - t)      # Up price at T before close
                if p is None or p == 0.5:
                    continue
                fav_is_up = p > 0.5
                fav_price = p if fav_is_up else (1 - p)
                fav_won = up_won if fav_is_up else (not up_won)
                n[t] += 1
                fav_win[t] += 1 if fav_won else 0
                fav_px[t].append(fav_price)
        if (i + 1) % 50 == 0:
            print(f"  {i+1}/{len(mkts)} ({used} used, {skip} skip)")

    print(f"  done: {used} usable, {skip} skipped")
    print(f"  {'T':>6} {'bets':>6} {'winrate':>8} {'avg_price':>10} {'edge':>9}")
    for t in lookbacks:
        if n[t] == 0:
            print(f"  {t//60:4d}m  (no data)"); continue
        wr = fav_win[t] / n[t]
        mp = st.mean(fav_px[t])
        tlab = f"{t//60}m" if t < 3600 else f"{t//3600}h"
        print(f"  {tlab:>6} {n[t]:6d} {wr*100:7.2f}% {mp:10.3f} {(wr-mp)*100:+8.2f}%")


def find_4h_series():
    """Try to locate the 4h up/down series id via public-search."""
    d, _ = get(f"{GAMMA}/public-search?q=bitcoin%20up%20or%20down%204%20hour&limit_per_type=40")
    ev = d.get("events", []) if isinstance(d, dict) else []
    for e in ev:
        for s in (e.get("series") or []):
            sl = (s.get("slug") or "")
            if "4h" in sl or "4-h" in sl or "four" in sl:
                return s.get("id"), sl
    return None, None


def main():
    test_series("HOURLY", HOURLY_SERIES, 3600, [300, 600, 900, 1800])
    sid, sl = find_4h_series()
    if sid:
        test_series(f"4H [{sl}]", sid, 14400, [900, 1800, 3600, 7200])
    else:
        print("\n#### 4H series not auto-found via search (will locate separately) ####")
    print("\nedge = favorite win_rate - avg price paid at real quotes.")
    print(">0 => underpriced (money on table);  <=0 => market prices momentum.")


if __name__ == "__main__":
    main()
