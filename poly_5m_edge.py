#!/usr/bin/env python3
"""TRUE-edge test on REAL Polymarket prices (btc-updown-5m markets the bot traded).

For each market we have, from the wallet's activity: the CLOB token id (`asset`)
and the window-open epoch (from slug `btc-updown-5m-<open>`). We pull the CLOB
price history (fidelity=1) and, for each lookback T before close, read the REAL
market price of the favorite side and whether it won at settlement.

Real edge = favorite_win_rate - mean(favorite_price_paid).  >0 => money left on
the table at real quoted prices; ~0 => the market already prices the momentum.
"""

import json
import time
import statistics as st
from urllib.request import urlopen, Request

WINDOW = 300
LOOKBACKS = [60, 120, 180]      # seconds before close
TOL = 40                        # match a history point within +-TOL sec
SAMPLE = 700                    # cap markets to keep runtime sane
CLOB = "https://clob.polymarket.com"
DATA = "https://data-api.polymarket.com"
ADDR = "0x21d0a97aac03917e752857a551bbe5103a00e8d7"


def get(url, want_nonempty=False):
    last = None
    for i in range(12):
        try:
            req = Request(url, headers={"User-Agent": "Mozilla/5.0"})
            d = json.loads(urlopen(req, timeout=30).read())
            if want_nonempty and isinstance(d, list) and not d:
                last = "empty"; time.sleep(0.5 * (i + 1)); continue
            return d, None
        except Exception as e:
            last = str(e); time.sleep(0.7 * (i + 1))
    return None, last


def fetch_activity():
    """Page the wallet's activity (500/page) until the 3000-offset cap."""
    rows = []
    offset = 0
    while True:
        url = f"{DATA}/activity?user={ADDR}&limit=500&offset={offset}"
        d, err = get(url)
        if err or not isinstance(d, list):
            break
        rows += d
        if len(d) < 500:
            break
        offset += 500
        if offset > 3000:
            break
    return rows


def settle_outcome(hist, close_ts):
    """Token settlement: last point at/after close. Returns 1 (won), 0 (lost), None."""
    after = [p for p in hist if p["t"] >= close_ts - 5]
    pts = after if after else hist
    if not pts:
        return None
    last = max(pts, key=lambda p: p["t"])["p"]
    if last >= 0.8:
        return 1
    if last <= 0.2:
        return 0
    return None


def price_at(hist, target):
    best = None
    for p in hist:
        d = abs(p["t"] - target)
        if d <= TOL and (best is None or d < best[0]):
            best = (d, p["p"])
    return best[1] if best else None


def main():
    print("Fetching wallet activity...")
    rows = fetch_activity()
    print(f"  {len(rows)} activity rows")

    # unique markets: conditionId -> (token asset, open epoch)
    markets = {}
    for r in rows:
        if r.get("type") != "TRADE":
            continue
        slug = r.get("slug") or ""
        if not slug.startswith("btc-updown-5m-"):
            continue
        cid = r.get("conditionId")
        if cid in markets:
            continue
        try:
            open_ep = int(slug.rsplit("-", 1)[1])
        except ValueError:
            continue
        markets[cid] = (r.get("asset"), open_ep)

    items = list(markets.items())[:SAMPLE]
    print(f"  {len(markets)} unique 5m markets; testing {len(items)}\n")

    fav_win = {t: 0 for t in LOOKBACKS}
    fav_px = {t: [] for t in LOOKBACKS}
    n = {t: 0 for t in LOOKBACKS}
    done = 0
    skipped = 0

    for cid, (tok, o) in items:
        c = o + WINDOW
        ph, err = get(f"{CLOB}/prices-history?market={tok}"
                      f"&startTs={o-30}&endTs={c+150}&fidelity=1")
        done += 1
        hist = ph.get("history", []) if isinstance(ph, dict) else []
        if len(hist) < 3:
            skipped += 1
        else:
            won = settle_outcome(hist, c)
            if won is None:
                skipped += 1
            else:
                for t in LOOKBACKS:
                    p = price_at(hist, c - t)          # this token's price at T
                    if p is None:
                        continue
                    fav_is_this = p > 0.5
                    fav_price = p if fav_is_this else (1 - p)
                    fav_won = won if fav_is_this else (1 - won)
                    n[t] += 1
                    fav_win[t] += fav_won
                    fav_px[t].append(fav_price)
        if done % 50 == 0:
            print(f"  {done}/{len(items)} markets ({skipped} skipped)")

    print(f"\nDone. {done} fetched, {skipped} unusable.\n")
    print("=== REAL Polymarket 5m favorite edge (buy leading side at real price) ===")
    print(f"  {'T(s)':>5} {'bets':>6} {'winrate':>8} {'avg_price':>10} "
          f"{'edge=win-price':>15}")
    for t in LOOKBACKS:
        if n[t] == 0:
            print(f"  {t:5d}  (no data)"); continue
        wr = fav_win[t] / n[t]
        mp = st.mean(fav_px[t])
        print(f"  {t:5d} {n[t]:6d} {wr*100:7.2f}% {mp:10.3f} {(wr-mp)*100:+14.2f}%")

    print("\nReading: edge>0 => favorite underpriced at REAL quotes (money on table).")
    print("         edge~0 or <0 => market already prices the momentum (no free edge).")


if __name__ == "__main__":
    main()
