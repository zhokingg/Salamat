#!/usr/bin/env python3
"""Break the wallet's edge down by underlying asset and market duration."""

from collections import defaultdict
import re
import statistics as st

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

import poly_pnl as P


def parse(slug):
    """Return (asset, duration) from a slug like 'btc-updown-15m-...' or hourly bitcoin slugs."""
    m = re.match(r"([a-z]+)-updown-(\d+m)", slug)
    if m:
        return m.group(1).upper(), m.group(2)
    if slug.startswith("bitcoin-up-or-down"):
        return "BTC", "1h"
    if slug.startswith("ethereum"):
        return "ETH", "1h"
    return "OTHER", "?"


def main():
    rows, status = P.fetch_all("/activity")
    if rows is None:
        raise SystemExit(f"failed HTTP {status}")

    # per-market aggregation, tagged with asset/duration from the buy legs
    mk = defaultdict(lambda: {"buy": 0.0, "red": 0.0, "ws": 0.0, "sh": 0.0,
                              "asset": None, "dur": None})
    for r in rows:
        t = P.classify(r)
        cond = r.get("conditionId")
        val = P.usdc_value(r)
        if t == "BUY":
            m = mk[cond]
            m["buy"] += val
            sz = P.num(r.get("size"))
            m["ws"] += P.num(r.get("price")) * sz
            m["sh"] += sz
            a, d = parse(r.get("slug", ""))
            m["asset"], m["dur"] = a, d
        elif t == "REDEEM":
            mk[cond]["red"] += val

    def agg(key_fn, title):
        groups = defaultdict(lambda: {"n": 0, "win": 0, "buy": 0.0, "red": 0.0, "entries": []})
        for m in mk.values():
            if m["buy"] <= 0 or m["asset"] is None:
                continue
            g = groups[key_fn(m)]
            g["n"] += 1
            net = m["red"] - m["buy"]
            g["win"] += 1 if net > 0 else 0
            g["buy"] += m["buy"]; g["red"] += m["red"]
            if m["sh"] > 0:
                g["entries"].append(m["ws"] / m["sh"])
        print(f"=== {title} ===")
        print(f"  {'group':8s} {'mkts':>5s} {'buy$':>9s} {'net$':>8s} {'ROC%':>7s} {'win%':>6s} {'avgEntry':>8s}")
        out = []
        for k in sorted(groups, key=lambda k: -groups[k]["buy"]):
            g = groups[k]
            net = g["red"] - g["buy"]
            roc = net / g["buy"] * 100
            wr = g["win"] / g["n"] * 100
            ae = st.mean(g["entries"]) if g["entries"] else 0
            print(f"  {k:8s} {g['n']:5d} {g['buy']:9.0f} {net:8.0f} {roc:7.2f} {wr:6.1f} {ae:8.3f}")
            out.append((k, g["n"], g["buy"], net, roc, wr))
        print()
        return out

    by_asset = agg(lambda m: m["asset"], "By asset")
    by_dur = agg(lambda m: m["dur"], "By duration")
    by_ad = agg(lambda m: f"{m['asset']}-{m['dur']}", "By asset x duration")

    # ---------- plot ----------
    fig, ax = plt.subplots(1, 2, figsize=(14, 5.5))

    labels = [r[0] for r in by_asset]
    net = [r[3] for r in by_asset]
    roc = [r[4] for r in by_asset]
    colors = ["#2ca02c" if n >= 0 else "#d62728" for n in net]
    bars = ax[0].bar(labels, net, color=colors)
    ax[0].axhline(0, color="grey", lw=0.8)
    ax[0].set_title("Net trading P&L by asset (USDC)")
    ax[0].set_ylabel("net USDC")
    for b, n, r_ in zip(bars, net, roc):
        ax[0].text(b.get_x() + b.get_width() / 2, n,
                   f"{n:,.0f}\n({r_:+.1f}%)", ha="center",
                   va="bottom" if n >= 0 else "top", fontsize=8)

    labels2 = [r[0] for r in by_ad]
    net2 = [r[3] for r in by_ad]
    colors2 = ["#2ca02c" if n >= 0 else "#d62728" for n in net2]
    bars2 = ax[1].bar(labels2, net2, color=colors2)
    ax[1].axhline(0, color="grey", lw=0.8)
    ax[1].set_title("Net trading P&L by asset x duration")
    ax[1].set_ylabel("net USDC")
    ax[1].tick_params(axis="x", rotation=40)
    for b, n in zip(bars2, net2):
        ax[1].text(b.get_x() + b.get_width() / 2, n, f"{n:,.0f}",
                   ha="center", va="bottom" if n >= 0 else "top", fontsize=7)

    plt.tight_layout()
    fig.savefig("poly_assets.png", dpi=130)
    print("Saved poly_assets.png")


if __name__ == "__main__":
    main()
