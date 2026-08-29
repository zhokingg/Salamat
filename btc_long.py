#!/usr/bin/env python3
"""Test the FAVORITE-momentum edge (buy the leading side T before close) on
   1-hour and 4-hour BTCUSDT windows, mirroring longer Polymarket up/down markets.

Uses 1m Binance klines over ~120 days for a decent sample. For each window we
take open at window start, the leading side at T sec before close, and the
outcome at close; we report win rate + binomial p-value and EV at a Brownian
no-drift fair price (same method as btc_edge2.py).
"""

import math
import time
import statistics as st

from scipy.stats import binomtest, norm

import btc_meanrev as B  # reuse fetch_klines / http_json / HOSTS

DAYS = 120
CONFIGS = [
    # (label, window_seconds, [lookbacks_before_close_seconds])
    ("1h", 3600,  [300, 600, 900, 1800]),     # 5m,10m,15m,30m before close
    ("4h", 14400, [900, 1800, 3600, 7200]),   # 15m,30m,1h,2h before close
]


def main():
    now_ms = int(time.time() * 1000) - 5000
    start_ms = now_ms - DAYS * 86400 * 1000
    start_ms = (start_ms // (4 * 3600 * 1000)) * (4 * 3600 * 1000)  # align to 4h

    print(f"Fetching ~{DAYS}d of {B.SYMBOL} 1m klines...")
    bars = B.fetch_klines("1m", start_ms, now_ms, 60_000)
    print(f"Fetched {len(bars)} 1m bars.\n")

    def at(sec):
        m = (sec // 60) * 60
        v = bars.get(m)
        return v  # (open, close) or None

    # 1m log-vol for the Brownian fair price
    secs = sorted(bars)
    rets, prev = [], None
    for s in secs:
        c = bars[s][1]
        if prev and prev > 0 and c > 0:
            rets.append(math.log(c / prev))
        prev = c
    sigma_min = st.pstdev(rets)
    sigma_sec = sigma_min / math.sqrt(60)
    print(f"1m log-vol sigma = {sigma_min:.6e}  "
          f"(~{sigma_min*math.sqrt(1440)*100:.2f}% daily)\n")

    start_s, end_s = start_ms // 1000, now_ms // 1000

    for label, window, lookbacks in CONFIGS:
        fav_wins = {t: 0 for t in lookbacks}
        n_bets = {t: 0 for t in lookbacks}
        ev_fav = {t: [] for t in lookbacks}
        fair_p = {t: [] for t in lookbacks}
        n_win = 0

        w = (start_s // window) * window
        while w + window <= end_s:
            ob = at(w)
            cb = at(w + window - 60)
            if ob is None or cb is None:
                w += window
                continue
            o, c = ob[0], cb[1]
            if c == o:
                w += window
                continue
            n_win += 1
            out_up = c > o
            for t in lookbacks:
                pb = at(w + window - t)
                if pb is None:
                    continue
                pT = pb[1]
                if pT == o:
                    continue
                fav_up = pT > o
                fav_correct = (fav_up == out_up)
                n_bets[t] += 1
                fav_wins[t] += 1 if fav_correct else 0
                z = abs(math.log(pT / o)) / (sigma_sec * math.sqrt(t))
                p_fair = norm.cdf(z)
                fair_p[t].append(p_fair)
                ev_fav[t].append((1.0 if fav_correct else 0.0) - p_fair)
            w += window

        print(f"================  {label} windows  ================")
        print(f"  usable windows: {n_win}")
        print(f"  {'T':>6} {'bets':>6} {'winrate':>8} {'excess':>8} "
              f"{'p(>50%)':>11} {'fair':>7} {'gap':>7} {'EV_fav':>8}")
        for t in lookbacks:
            n, k = n_bets[t], fav_wins[t]
            if n == 0:
                print(f"  {t//60:4d}m  (no bets)")
                continue
            wr = k / n
            bt = binomtest(k, n, 0.5, alternative="greater")
            fair = st.mean(fair_p[t])
            ef = st.mean(ev_fav[t])
            tlab = f"{t//60}m" if t < 3600 else f"{t//3600}h"
            print(f"  {tlab:>6} {n:6d} {wr*100:7.2f}% {(wr-0.5)*100:+7.2f}% "
                  f"{bt.pvalue:11.3g} {fair*100:6.1f}% {(wr-fair)*100:+6.1f}% "
                  f"{ef:+8.4f}")
        print()

    print("Reading:")
    print("  winrate>>50% w/ tiny p  => leading side persists at this horizon.")
    print("  gap=winrate-fair >0 & EV_fav>0 => favorite underpriced (real edge).")
    print("  gap~0 / EV_fav~0 => persistence is just fair random-walk pricing (no edge).")


if __name__ == "__main__":
    main()
