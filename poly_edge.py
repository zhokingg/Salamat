#!/usr/bin/env python3
"""Test two strategy hypotheses for the wallet:
   1. Does the edge come from pricing (entry < fair) or from rebates?
   2. Are 'both outcomes bought' markets genuine arbitrage hedges or just re-quoting?
"""

from collections import defaultdict
import statistics as st

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

import poly_pnl as P


def main():
    rows, status = P.fetch_all("/activity")
    if rows is None:
        raise SystemExit(f"failed HTTP {status}")

    # Aggregate per market (conditionId)
    mk = defaultdict(lambda: {
        "buy_cost": 0.0, "redeem": 0.0,
        "shares": defaultdict(float),   # outcome -> shares bought
        "cost": defaultdict(float),     # outcome -> usdc spent
        "buy_usdc_wsum": 0.0, "buy_shares": 0.0,
    })
    rebate_total = 0.0
    for r in rows:
        t = P.classify(r)
        cond = r.get("conditionId")
        val = P.usdc_value(r)
        if t == "BUY":
            m = mk[cond]
            m["buy_cost"] += val
            sz = P.num(r.get("size"))
            m["shares"][r.get("outcome")] += sz
            m["cost"][r.get("outcome")] += val
            m["buy_usdc_wsum"] += P.num(r.get("price")) * sz
            m["buy_shares"] += sz
        elif t == "REDEEM":
            mk[cond]["redeem"] += val
        elif "REWARD" in t or "REBATE" in t:
            rebate_total += val

    markets = list(mk.values())

    # ---------- Hypothesis 1: pricing vs rebates ----------
    total_buy = sum(m["buy_cost"] for m in markets)
    total_redeem = sum(m["redeem"] for m in markets)
    gross_trading = total_redeem - total_buy
    print("=== Hypothesis 1: pricing edge vs rebate edge ===")
    print(f"  total buy cost   : {total_buy:10.2f}")
    print(f"  total redeem     : {total_redeem:10.2f}")
    print(f"  gross trading P&L: {gross_trading:10.2f}  (return on cost {gross_trading/total_buy*100:5.2f}%)")
    print(f"  rebates/rewards  : {rebate_total:10.2f}")
    print(f"  total net        : {gross_trading + rebate_total:10.2f}")
    print(f"  --> rebates are {rebate_total/(gross_trading+rebate_total)*100:.1f}% of total profit\n")

    # Win rate & return by entry-price bucket (volume-weighted avg entry per market)
    buckets = defaultdict(lambda: {"n": 0, "win": 0, "buy": 0.0, "red": 0.0})
    pts_price, pts_ret = [], []
    for m in markets:
        if m["buy_shares"] <= 0 or m["buy_cost"] <= 0:
            continue
        avg_entry = m["buy_usdc_wsum"] / m["buy_shares"]
        b = round(avg_entry * 10) / 10
        net = m["redeem"] - m["buy_cost"]
        buckets[b]["n"] += 1
        buckets[b]["win"] += 1 if net > 0 else 0
        buckets[b]["buy"] += m["buy_cost"]
        buckets[b]["red"] += m["redeem"]
        pts_price.append(avg_entry)
        pts_ret.append(net / m["buy_cost"] * 100)

    print("=== Win rate & return by avg entry price (per market) ===")
    print("  entry   markets  winrate   return-on-cost")
    bx, b_win, b_ret = [], [], []
    for b in sorted(buckets):
        d = buckets[b]
        wr = d["win"] / d["n"] * 100
        roc = (d["red"] - d["buy"]) / d["buy"] * 100 if d["buy"] else 0
        print(f"  {b:.1f}    {d['n']:5d}   {wr:5.1f}%   {roc:7.2f}%")
        bx.append(b); b_win.append(wr); b_ret.append(roc)
    print()

    # ---------- Hypothesis 2: both-sides markets ----------
    both = [m for m in markets if len([o for o, s in m["shares"].items() if s > 0]) > 1]
    print(f"=== Hypothesis 2: both-outcomes markets (n={len(both)}) ===")
    arb = 0
    pair_costs = []
    for m in both:
        ss = [s for s in m["shares"].values() if s > 0]
        matched = min(ss)                     # guaranteed-redeem shares
        cost_per_pair = m["buy_cost"] / matched if matched else 0
        pair_costs.append(cost_per_pair)
        # arbitrage if combined cost to hold a matched pair < $1 (locks risk-free profit)
        # approximate per-pair price = sum of vol-weighted prices across both legs
        if cost_per_pair < 1.0 and matched > 0:
            arb += 1
    if pair_costs:
        print(f"  cost to hold a matched (Up+Down) pair, USDC:")
        print(f"    min={min(pair_costs):.3f} median={st.median(pair_costs):.3f} "
              f"mean={st.mean(pair_costs):.3f} max={max(pair_costs):.3f}")
        print(f"  markets where matched-pair cost < $1.00 (risk-free lock): {arb}/{len(both)}")
        # imbalance: how lopsided are the two legs (1.0 = perfect hedge)
        imb = []
        for m in both:
            ss = sorted([s for s in m["shares"].values() if s > 0])
            imb.append(ss[0] / ss[-1])
        print(f"  leg balance (smaller/larger shares): median={st.median(imb):.2f} "
              f"(1.0=perfect hedge, ~0=mostly one side)")

    # ---------- Plot ----------
    fig, ax = plt.subplots(1, 2, figsize=(14, 5))
    ax2 = ax[0].twinx()
    ax[0].bar(bx, [buckets[b]["n"] for b in bx], width=0.08, color="#cccccc", label="markets")
    ax2.plot(bx, b_win, "o-", color="#1f77b4", label="win rate %")
    ax2.plot(bx, b_ret, "s--", color="#d62728", label="return on cost %")
    ax2.axhline(50, color="#1f77b4", lw=0.6, ls=":")
    ax2.axhline(0, color="#d62728", lw=0.6, ls=":")
    ax[0].set_xlabel("avg entry price"); ax[0].set_ylabel("# markets")
    ax2.set_ylabel("win rate / return %")
    ax[0].set_title("H1: win rate & return by entry price")
    lines = ax2.get_lines()
    ax2.legend(loc="upper center", fontsize=8)

    ax[1].hist([min(1.6, c) for c in pair_costs], bins=30, color="#2ca02c", alpha=0.8)
    ax[1].axvline(1.0, color="black", lw=1.5, label="$1.00 break-even\n(left = risk-free profit)")
    ax[1].set_xlabel("cost to hold a matched Up+Down pair (USDC)")
    ax[1].set_ylabel("# both-sides markets")
    ax[1].set_title("H2: are both-sides markets arbitrage?")
    ax[1].legend(fontsize=8)

    plt.tight_layout()
    fig.savefig("poly_edge.png", dpi=130)
    print("\nSaved poly_edge.png")


if __name__ == "__main__":
    main()
