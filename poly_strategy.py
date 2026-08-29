#!/usr/bin/env python3
"""Infer the trading strategy of the wallet from its observable activity."""

from collections import Counter, defaultdict
from datetime import datetime, timezone
import re
import statistics as st

import poly_pnl as P


def main():
    rows, status = P.fetch_all("/activity")
    if rows is None:
        raise SystemExit(f"failed HTTP {status}")
    rows.sort(key=lambda r: P.num(r.get("timestamp")))

    trades = [r for r in rows if P.classify(r) == "BUY"]
    redeems = [r for r in rows if P.classify(r) == "REDEEM"]
    sells = [r for r in rows if P.classify(r) == "SELL"]

    print(f"Window: {datetime.fromtimestamp(P.num(rows[0]['timestamp']), timezone.utc)}"
          f"  ->  {datetime.fromtimestamp(P.num(rows[-1]['timestamp']), timezone.utc)} UTC")
    print(f"rows={len(rows)} buys={len(trades)} sells={len(sells)} redeems={len(redeems)}\n")

    # Market families (from slug prefix like btc-updown-15m / btc-updown-5m)
    fam = Counter()
    for r in trades:
        slug = r.get("slug", "")
        m = re.match(r"([a-z]+-[a-z]+-\d+m)", slug)
        fam[m.group(1) if m else slug] += 1
    print("=== Market families traded (by buy count) ===")
    for k, v in fam.most_common(10):
        print(f"  {k:22s} {v}")
    print()

    # Up vs Down preference
    out = Counter(r.get("outcome") for r in trades)
    print("=== Outcome chosen on BUY ===")
    for k, v in out.most_common():
        print(f"  {k}: {v}")
    print()

    # Entry price distribution
    prices = [P.num(r.get("price")) for r in trades if r.get("price")]
    if prices:
        buckets = Counter()
        for p in prices:
            buckets[round(p * 10) / 10] += 1
        print("=== Entry price distribution (BUY) ===")
        print(f"  min={min(prices):.2f} median={st.median(prices):.2f} "
              f"mean={st.mean(prices):.2f} max={max(prices):.2f}")
        for b in sorted(buckets):
            bar = "#" * int(buckets[b] / max(buckets.values()) * 40)
            print(f"  {b:.1f}  {buckets[b]:4d} {bar}")
        print()

    # Position sizing (USDC per buy)
    sizes = [P.usdc_value(r) for r in trades]
    if sizes:
        print("=== Position size per BUY (USDC) ===")
        print(f"  min={min(sizes):.2f} median={st.median(sizes):.2f} "
              f"mean={st.mean(sizes):.2f} max={max(sizes):.2f}")
        print()

    # Trading frequency: gaps between consecutive buys
    ts = sorted(P.num(r["timestamp"]) for r in trades)
    gaps = [b - a for a, b in zip(ts, ts[1:]) if b - a >= 0]
    if gaps:
        print("=== Seconds between consecutive BUYs ===")
        print(f"  median={st.median(gaps):.0f}s  mean={st.mean(gaps):.0f}s  "
              f"max={max(gaps):.0f}s")
        print()

    # Multiple buys per market? (averaging in / scaling)
    buys_per_cond = Counter(r.get("conditionId") for r in trades)
    multi = sum(1 for c, n in buys_per_cond.items() if n > 1)
    print("=== Buys per market ===")
    print(f"  distinct markets bought: {len(buys_per_cond)}")
    print(f"  markets with >1 buy: {multi} "
          f"(max buys in one market: {max(buys_per_cond.values())})")

    # Does it buy BOTH outcomes in the same market? (hedge / arbitrage signal)
    sides_per_cond = defaultdict(set)
    for r in trades:
        sides_per_cond[r.get("conditionId")].add(r.get("outcome"))
    both = sum(1 for c, s in sides_per_cond.items() if len(s) > 1)
    print(f"  markets where BOTH outcomes were bought: {both}")


if __name__ == "__main__":
    main()
