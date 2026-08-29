#!/usr/bin/env python3
"""Fetch Polymarket activity (via poly_pnl) and render P&L / activity charts to PNG."""

from datetime import datetime, timezone

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import matplotlib.dates as mdates

import poly_pnl as P


def load():
    rows, status = P.fetch_all("/activity")
    if rows is None:
        raise SystemExit(f"/activity failed (HTTP {status})")
    rows.sort(key=lambda r: P.num(r.get("timestamp")))
    return rows


def main():
    rows = load()
    print(f"Loaded {len(rows)} rows")

    times, cum_pnl, cum_with_rw = [], [], []
    running = running_rw = 0.0
    by_type = {}
    daily = {}  # date -> {'buy':, 'redeem':}

    for r in rows:
        t = P.classify(r)
        val = P.usdc_value(r)
        by_type[t] = by_type.get(t, 0.0) + val
        ts = P.num(r.get("timestamp"))
        dt = datetime.fromtimestamp(ts, tz=timezone.utc)

        delta = 0.0
        if t == "BUY":
            delta = -val
        elif t in ("SELL", "REDEEM"):
            delta = val
        running += delta
        rw = val if ("REWARD" in t or "REBATE" in t) else 0.0
        running_rw += delta + rw

        times.append(dt)
        cum_pnl.append(running)
        cum_with_rw.append(running_rw)

        day = dt.date()
        d = daily.setdefault(day, {"buy": 0.0, "redeem": 0.0})
        if t == "BUY":
            d["buy"] += val
        elif t == "REDEEM":
            d["redeem"] += val

    fig, axes = plt.subplots(2, 2, figsize=(15, 9))
    fig.suptitle("Polymarket wallet 0x21d0…e8d7 (PBot-6) — last ~3,500 activities",
                 fontsize=13, fontweight="bold")

    # 1. Cumulative P&L over time
    ax = axes[0][0]
    ax.plot(times, cum_pnl, color="#1f77b4", lw=1.4, label="Net (redeems − buys)")
    ax.plot(times, cum_with_rw, color="#2ca02c", lw=1.4, ls="--", label="Net + rewards")
    ax.axhline(0, color="grey", lw=0.8)
    ax.fill_between(times, cum_pnl, 0, where=[v >= 0 for v in cum_pnl],
                    color="#2ca02c", alpha=0.12)
    ax.fill_between(times, cum_pnl, 0, where=[v < 0 for v in cum_pnl],
                    color="#d62728", alpha=0.12)
    ax.set_title("Cumulative P&L (USDC)")
    ax.set_ylabel("USDC")
    ax.legend(loc="upper left", fontsize=8)
    ax.xaxis.set_major_formatter(mdates.DateFormatter("%m-%d\n%H:%M"))

    # 2. Activity breakdown by USDC
    ax = axes[0][1]
    items = sorted(by_type.items(), key=lambda kv: -kv[1])
    labels = [k for k, _ in items]
    vals = [v for _, v in items]
    bars = ax.bar(labels, vals, color="#ff7f0e")
    ax.set_title("USDC volume by activity type")
    ax.set_ylabel("USDC")
    ax.tick_params(axis="x", rotation=25)
    for b, v in zip(bars, vals):
        ax.text(b.get_x() + b.get_width() / 2, v, f"{v:,.0f}",
                ha="center", va="bottom", fontsize=8)

    # 3. Daily buys vs redeems
    ax = axes[1][0]
    days = sorted(daily)
    buys = [daily[d]["buy"] for d in days]
    reds = [daily[d]["redeem"] for d in days]
    x = range(len(days))
    w = 0.4
    ax.bar([i - w / 2 for i in x], buys, w, label="Buys", color="#d62728")
    ax.bar([i + w / 2 for i in x], reds, w, label="Redeems", color="#2ca02c")
    ax.set_title("Daily buys vs redeems (USDC)")
    ax.set_ylabel("USDC")
    ax.set_xticks(list(x))
    ax.set_xticklabels([d.strftime("%m-%d") for d in days], rotation=45, fontsize=7)
    ax.legend(fontsize=8)

    # 4. Win/loss by market
    ax = axes[1][1]
    net_by_cond = {}
    for r in rows:
        t = P.classify(r)
        cond = r.get("conditionId") or "?"
        val = P.usdc_value(r)
        if t == "BUY":
            net_by_cond[cond] = net_by_cond.get(cond, 0.0) - val
        elif t in ("SELL", "REDEEM"):
            net_by_cond[cond] = net_by_cond.get(cond, 0.0) + val
    nets = [v for c, v in net_by_cond.items() if c != "?"]
    wins = sum(1 for v in nets if v > 0)
    losses = len(nets) - wins
    ax.pie([wins, losses], labels=[f"Win\n{wins}", f"Loss\n{losses}"],
           autopct="%1.1f%%", colors=["#2ca02c", "#d62728"],
           startangle=90, wedgeprops={"width": 0.45})
    ax.set_title(f"Win rate by market (n={len(nets)})")

    plt.tight_layout(rect=[0, 0, 1, 0.96])
    out = "poly_pnl.png"
    fig.savefig(out, dpi=130)
    print(f"Saved {out}")


if __name__ == "__main__":
    main()
