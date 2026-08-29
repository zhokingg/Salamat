#!/usr/bin/env python3
"""Visualize the win-rate vs return divergence per asset:
   a maker that wins often but loses money has small wins and fat-tailed losses.
"""

from collections import defaultdict
import re
import statistics as st

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

import poly_pnl as P


def asset_of(slug):
    m = re.match(r"([a-z]+)-updown-\d+m", slug or "")
    if m:
        return m.group(1).upper()
    if (slug or "").startswith("bitcoin-up-or-down"):
        return "BTC"
    return "OTHER"


def main():
    rows, status = P.fetch_all("/activity")
    if rows is None:
        raise SystemExit(f"failed HTTP {status}")

    mk = defaultdict(lambda: {"buy": 0.0, "red": 0.0, "asset": None})
    for r in rows:
        t = P.classify(r)
        cond = r.get("conditionId")
        if t == "BUY":
            m = mk[cond]
            m["buy"] += P.usdc_value(r)
            m["asset"] = asset_of(r.get("slug"))
        elif t == "REDEEM":
            mk[cond]["red"] += P.usdc_value(r)

    by_asset = defaultdict(list)  # asset -> list of per-market net
    for m in mk.values():
        if m["buy"] > 0 and m["asset"]:
            by_asset[m["asset"]].append(m["red"] - m["buy"])

    assets = sorted(by_asset, key=lambda a: -sum(by_asset[a]) if by_asset[a] else 0)
    assets = [a for a in assets if len(by_asset[a]) >= 5]

    print(f"  {'asset':6s} {'n':>4s} {'win%':>6s} {'avgWin':>8s} {'avgLoss':>8s} "
          f"{'worst':>8s} {'expectancy':>10s}")
    stats = {}
    for a in assets:
        nets = by_asset[a]
        wins = [x for x in nets if x > 0]
        losses = [x for x in nets if x <= 0]
        wr = len(wins) / len(nets) * 100
        aw = st.mean(wins) if wins else 0
        al = st.mean(losses) if losses else 0
        worst = min(nets)
        exp = st.mean(nets)
        stats[a] = (len(nets), wr, aw, al, worst, exp)
        print(f"  {a:6s} {len(nets):4d} {wr:6.1f} {aw:8.3f} {al:8.3f} {worst:8.2f} {exp:10.3f}")

    fig, ax = plt.subplots(1, 3, figsize=(16, 5))

    # Panel 1: win rate vs expectancy (the divergence)
    a1 = ax[0]
    x = range(len(assets))
    wr = [stats[a][1] for a in assets]
    a1b = a1.twinx()
    bars = a1.bar(x, wr, color="#9ecae1", label="win rate %")
    a1.axhline(50, color="#3182bd", ls=":", lw=0.8)
    exp = [stats[a][5] for a in assets]
    a1b.plot(x, exp, "ko-", label="avg P&L per market (USDC)")
    a1b.axhline(0, color="black", ls=":", lw=0.8)
    a1.set_xticks(list(x)); a1.set_xticklabels(assets)
    a1.set_ylabel("win rate %"); a1b.set_ylabel("avg P&L / market (USDC)")
    a1.set_title("Win rate is HIGH where P&L is NEGATIVE")
    for i, a in enumerate(assets):
        a1b.annotate(f"{exp[i]:+.2f}", (i, exp[i]), textcoords="offset points",
                     xytext=(0, 8), ha="center", fontsize=8)

    # Panel 2: average win vs average loss size
    a2 = ax[1]
    w = 0.38
    aw = [stats[a][2] for a in assets]
    al = [abs(stats[a][3]) for a in assets]
    a2.bar([i - w/2 for i in x], aw, w, color="#2ca02c", label="avg WIN size")
    a2.bar([i + w/2 for i in x], al, w, color="#d62728", label="avg LOSS size")
    a2.set_xticks(list(x)); a2.set_xticklabels(assets)
    a2.set_ylabel("USDC per market")
    a2.set_title("Small wins vs large losses (picked-off maker)")
    a2.legend(fontsize=8)

    # Panel 3: per-market P&L distribution (fat left tail)
    a3 = ax[2]
    data = [by_asset[a] for a in assets]
    parts = a3.violinplot(data, showmeans=True, showextrema=True)
    a3.axhline(0, color="grey", lw=0.8)
    a3.set_xticks(range(1, len(assets) + 1)); a3.set_xticklabels(assets)
    a3.set_ylabel("per-market net P&L (USDC)")
    a3.set_title("P&L distribution: fat negative tails")

    plt.tight_layout()
    fig.savefig("poly_divergence.png", dpi=130)
    print("\nSaved poly_divergence.png")


if __name__ == "__main__":
    main()
