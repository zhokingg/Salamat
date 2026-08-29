#!/usr/bin/env python3
"""Test a mean-reversion 'buy the cheap side T sec before close' edge on 5-minute
   BTCUSDT windows, mimicking Polymarket btc-updown-5m markets, using public Binance data.

No API key required. Pulls 1s klines for ~7 days (falls back to 1m if 1s unavailable),
slices into :00/:05/:10... aligned 5-min windows, and for each lookback T measures how
often the 'underdog' (side opposite the move at T-sec-before-close) wins at the window close.
"""

import json
import time
import math
from urllib.request import urlopen, Request
from urllib.error import HTTPError, URLError

from scipy.stats import binomtest

SYMBOL = "BTCUSDT"
DAYS = 7
WINDOW = 300                     # 5 minutes in seconds
LOOKBACKS = [60, 90, 120, 180]   # seconds before window close
HOSTS = ["https://api.binance.com", "https://api1.binance.com",
         "https://api2.binance.com", "https://data-api.binance.vision"]


def http_json(path):
    last = None
    for host in HOSTS:
        for attempt in range(3):
            try:
                req = Request(host + path, headers={"User-Agent": "Mozilla/5.0"})
                with urlopen(req, timeout=30) as r:
                    return json.loads(r.read().decode())
            except (HTTPError, URLError) as e:
                last = e
                time.sleep(0.5 * (attempt + 1))
    raise last


def fetch_klines(interval, start_ms, end_ms, step_ms):
    """Paginate klines by startTime. Returns dict: second_ts -> (open, close)."""
    out = {}
    cur = start_ms
    reqs = 0
    total_span = max(1, end_ms - start_ms)
    while cur < end_ms:
        path = (f"/api/v3/klines?symbol={SYMBOL}&interval={interval}"
                f"&startTime={cur}&endTime={end_ms}&limit=1000")
        data = http_json(path)
        reqs += 1
        if not data:
            break
        for k in data:
            sec = k[0] // 1000
            out[sec] = (float(k[1]), float(k[4]))  # open, close
        last_open = data[-1][0]
        cur = last_open + step_ms
        if reqs % 25 == 0 or cur >= end_ms:
            pct = min(100, (cur - start_ms) / total_span * 100)
            done = time.strftime("%m-%d %H:%M", time.gmtime(last_open / 1000))
            print(f"  [{interval}] {reqs:4d} reqs, {len(out):7d} bars, "
                  f"up to {done}Z ({pct:4.0f}%)")
        if len(data) < 1000 and interval != "1s":
            # 1m fully paginated when short page; 1s pages are always ~1000
            pass
        time.sleep(0.04)
    return out


def pct_stats(vals):
    vals = sorted(vals)
    n = len(vals)
    if not n:
        return (0, 0, 0, 0)
    def q(p):
        return vals[min(n - 1, int(p * n))]
    return (vals[0], q(0.5), q(0.9), vals[-1])


def main():
    now_ms = int(time.time() * 1000) - 5000          # small safety margin
    start_ms = now_ms - DAYS * 86400 * 1000
    # align start to a 5-min boundary
    start_ms = (start_ms // (WINDOW * 1000)) * (WINDOW * 1000)

    print(f"Fetching ~{DAYS}d of {SYMBOL} klines (1s)...")
    interval, step = "1s", 1000
    bars = fetch_klines("1s", start_ms, now_ms, step)
    resolution = 1
    if len(bars) < DAYS * 86400 * 0.5:
        print(f"  1s coverage thin ({len(bars)} bars); falling back to 1m resolution.")
        bars = fetch_klines("1m", start_ms, now_ms, 60_000)
        interval, step, resolution = "1m", 60_000, 60

    print(f"Fetched {len(bars)} bars at {interval} resolution.\n")

    def price_at(sec):
        """Price as of end of given second (close). For 1m res, snap down to minute."""
        if resolution == 1:
            v = bars.get(sec)
            return v[1] if v else None
        minute = (sec // 60) * 60
        v = bars.get(minute)
        return v[1] if v else None

    def open_at(sec):
        if resolution == 1:
            v = bars.get(sec)
            return v[0] if v else None
        minute = (sec // 60) * 60
        v = bars.get(minute)
        return v[0] if v else None

    usable_T = [t for t in LOOKBACKS if resolution == 1 or t % 60 == 0]
    if usable_T != LOOKBACKS:
        print(f"  NOTE: 1m resolution -> only T in {usable_T} are exact (T not /60 dropped).\n")

    start_s = start_ms // 1000
    end_s = now_ms // 1000

    # accumulate per-T results
    wins = {t: 0 for t in usable_T}
    bets = {t: 0 for t in usable_T}
    abs_move_T = {t: [] for t in usable_T}
    abs_close = []
    n_windows = 0
    skipped = 0

    w = (start_s // WINDOW) * WINDOW
    while w + WINDOW <= end_s:
        o = open_at(w)
        c = price_at(w + WINDOW - 1)
        if o is None or c is None:
            skipped += 1
            w += WINDOW
            continue
        n_windows += 1
        abs_close.append(abs(c - o))
        # outcome: Up if close>open, Down if close<open; skip exact ties
        out_up = c > o
        if c == o:
            w += WINDOW
            continue
        for t in usable_T:
            pT = price_at(w + WINDOW - t)
            if pT is None or pT == o:
                continue
            up_leading = pT > o            # at T-before-close, Up is ahead
            underdog_up = not up_leading    # underdog = opposite side
            underdog_wins = (underdog_up == out_up)
            bets[t] += 1
            wins[t] += 1 if underdog_wins else 0
            abs_move_T[t].append(abs(pT - o))
        w += WINDOW

    print(f"Windows: {n_windows} usable, {skipped} skipped (gaps).\n")

    # scale stats
    mn, md, p90, mx = pct_stats(abs_close)
    print("Move-size scale (|close - open|), USDT:")
    print(f"  min={mn:.2f} median={md:.2f} p90={p90:.2f} max={mx:.2f}\n")

    print("=== Underdog win rate by lookback T (buy cheap side T sec before close) ===")
    print(f"  {'T(s)':>5} {'bets':>6} {'wins':>6} {'winrate':>8} {'excess':>8} "
          f"{'p-value':>10} {'|move_T| med':>12}")
    for t in usable_T:
        n, k = bets[t], wins[t]
        if n == 0:
            print(f"  {t:5d}  (no bets)")
            continue
        wr = k / n
        bt = binomtest(k, n, 0.5, alternative="greater")
        _, mm, _, _ = pct_stats(abs_move_T[t])
        sig = "***" if bt.pvalue < 0.001 else "**" if bt.pvalue < 0.01 else \
              "*" if bt.pvalue < 0.05 else ""
        print(f"  {t:5d} {n:6d} {k:6d} {wr*100:7.2f}% {(wr-0.5)*100:+7.2f}% "
              f"{bt.pvalue:10.4g} {mm:11.2f}  {sig}")

    print("\nBaseline (random walk) win rate = 50.00%.")
    print("Reading: win rate stably & significantly >50% => mean-reversion edge is real;")
    print("         ~50% with large p-value => mirage (no edge).")


if __name__ == "__main__":
    main()
