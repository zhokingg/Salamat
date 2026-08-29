#!/usr/bin/env python3
"""Follow-up to btc_meanrev.py:
   (a) Quantify the FAVORITE (momentum) win rate by T with binomial p-values.
   (b) Estimate EV of buying favorite vs underdog at a Brownian no-drift 'fair' price,
       to distinguish a real momentum mispricing from efficient pricing.

Caches the 1s klines to btc_bars.pkl so reruns are instant.
"""

import os
import pickle
import math
import time

from scipy.stats import binomtest, norm

import btc_meanrev as B  # reuse fetch_klines / constants

CACHE = "btc_bars.pkl"
WINDOW = B.WINDOW
LOOKBACKS = B.LOOKBACKS


def load_bars():
    if os.path.exists(CACHE):
        with open(CACHE, "rb") as f:
            d = pickle.load(f)
        print(f"Loaded {len(d['bars'])} cached 1s bars.")
        return d["bars"], d["start_s"], d["end_s"]
    now_ms = int(time.time() * 1000) - 5000
    start_ms = now_ms - B.DAYS * 86400 * 1000
    start_ms = (start_ms // (WINDOW * 1000)) * (WINDOW * 1000)
    print("Fetching 1s klines (will cache)...")
    bars = B.fetch_klines("1s", start_ms, now_ms, 1000)
    start_s, end_s = start_ms // 1000, now_ms // 1000
    with open(CACHE, "wb") as f:
        pickle.dump({"bars": bars, "start_s": start_s, "end_s": end_s}, f)
    print(f"Fetched & cached {len(bars)} bars.")
    return bars, start_s, end_s


def main():
    bars, start_s, end_s = load_bars()

    # per-second log returns for volatility estimate
    secs = sorted(bars)
    import statistics as st
    rets = []
    prev = None
    for s in secs:
        c = bars[s][1]
        if prev is not None and prev > 0 and c > 0:
            rets.append(math.log(c / prev))
        prev = c
    sigma_sec = st.pstdev(rets)
    print(f"Estimated 1s log-vol sigma = {sigma_sec:.6e}  "
          f"(~{sigma_sec*math.sqrt(86400)*100:.2f}% daily)\n")

    def price_at(sec):
        v = bars.get(sec)
        return v[1] if v else None

    def open_at(sec):
        v = bars.get(sec)
        return v[0] if v else None

    fav_wins = {t: 0 for t in LOOKBACKS}
    n_bets = {t: 0 for t in LOOKBACKS}
    # EV accumulators (per $1 binary contract, payoff 1 if win else 0)
    ev_fav = {t: [] for t in LOOKBACKS}
    ev_dog = {t: [] for t in LOOKBACKS}
    fair_fav_price = {t: [] for t in LOOKBACKS}

    w = (start_s // WINDOW) * WINDOW
    while w + WINDOW <= end_s:
        o = open_at(w)
        c = price_at(w + WINDOW - 1)
        if o is None or c is None or c == o:
            w += WINDOW
            continue
        out_up = c > o
        for t in LOOKBACKS:
            pT = price_at(w + WINDOW - t)
            if pT is None or pT == o:
                continue
            up_leading = pT > o
            favorite_up = up_leading
            fav_correct = (favorite_up == out_up)
            n_bets[t] += 1
            fav_wins[t] += 1 if fav_correct else 0

            # Brownian no-drift fair price of the FAVORITE:
            # z = |log(pT/o)| / (sigma * sqrt(T)); P(stay on same side) = Phi(z)
            z = abs(math.log(pT / o)) / (sigma_sec * math.sqrt(t))
            p_fair_fav = norm.cdf(z)              # fair favorite price
            p_fair_dog = 1 - p_fair_fav            # fair underdog price
            fair_fav_price[t].append(p_fair_fav)

            # EV of buying each side at its fair price (payoff 1 if that side wins)
            ev_fav[t].append((1.0 if fav_correct else 0.0) - p_fair_fav)
            ev_dog[t].append((0.0 if fav_correct else 1.0) - p_fair_dog)
        w += WINDOW

    print("=== (a) FAVORITE (momentum) win rate by T ===")
    print(f"  {'T(s)':>5} {'bets':>6} {'winrate':>8} {'excess':>8} {'p(>50%)':>12}")
    for t in LOOKBACKS:
        n, k = n_bets[t], fav_wins[t]
        wr = k / n
        bt = binomtest(k, n, 0.5, alternative="greater")
        print(f"  {t:5d} {n:6d} {wr*100:7.2f}% {(wr-0.5)*100:+7.2f}% {bt.pvalue:12.3g}")

    print("\n=== (b) Calibration: actual favorite win rate vs Brownian-fair price ===")
    print(f"  {'T(s)':>5} {'actual_win':>11} {'fair_price':>11} {'gap(act-fair)':>14}")
    for t in LOOKBACKS:
        import statistics as st
        actual = fav_wins[t] / n_bets[t]
        fair = st.mean(fair_fav_price[t])
        print(f"  {t:5d} {actual*100:10.2f}% {fair*100:10.2f}% {(actual-fair)*100:+13.2f}%")

    print("\n=== (b) EV per $1 contract at Brownian-fair prices ===")
    print(f"  {'T(s)':>5} {'EV_favorite':>12} {'EV_underdog':>12}   (>0 = profitable)")
    import statistics as st
    for t in LOOKBACKS:
        ef = st.mean(ev_fav[t])
        ed = st.mean(ev_dog[t])
        print(f"  {t:5d} {ef:+12.4f} {ed:+12.4f}")

    print("\nReading:")
    print("  (a) favorite winrate >>50%, p~0  => strong momentum/persistence near expiry.")
    print("  (b) if actual_win > fair_price (positive gap) and EV_favorite>0, the favorite")
    print("      is UNDERPRICED under a fair random walk => momentum mispricing is real,")
    print("      and the underdog (cheap side) is a NEGATIVE-EV bet even at 'fair' odds.")


if __name__ == "__main__":
    main()
