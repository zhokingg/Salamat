#!/usr/bin/env python3
"""Fetch full Polymarket activity history for a wallet and compute cash flow + win rate."""

import sys
import time
import json
from collections import defaultdict
from urllib.request import urlopen, Request
from urllib.error import HTTPError, URLError

ADDR = "0x21d0a97aac03917e752857a551bbe5103a00e8d7"
BASE = "https://data-api.polymarket.com"


def http_get(url, retries=3):
    """GET JSON. Retries only transient network/5xx errors; raises HTTPError on 4xx immediately."""
    last = None
    for attempt in range(retries):
        try:
            req = Request(url, headers={"User-Agent": "Mozilla/5.0", "Accept": "application/json"})
            with urlopen(req, timeout=30) as resp:
                return resp.status, json.loads(resp.read().decode("utf-8"))
        except HTTPError as e:
            # 4xx are not transient (bad params, offset cap, not found): surface immediately.
            e.body = ""
            try:
                e.body = e.read()[:300].decode("utf-8", "replace")
            except Exception:
                pass
            raise
        except URLError as e:
            last = e
            if attempt < retries - 1:
                time.sleep(2.0 * (attempt + 1))
    raise last


def fetch_all(endpoint):
    """Paginate limit/offset by 500. Returns (list, first_status).

    /activity hard-caps offset at 3000 ("max historical activity offset exceeded"). When we
    page past it we keep everything collected so far instead of discarding it.
    """
    rows = []
    limit = 500
    offset = 0
    first_status = None
    while True:
        url = f"{BASE}{endpoint}?user={ADDR}&limit={limit}&offset={offset}"
        try:
            status, data = http_get(url)
        except HTTPError as e:
            body = getattr(e, "body", "")
            if rows:  # paginated past the offset cap (or similar) — keep what we have
                print(f"  stopping pagination at offset={offset}: HTTP {e.code} {body}")
                return rows, first_status
            return None, e.code  # failed on the very first page
        except URLError as e:
            print(f"  network error: {e}")
            return (rows, first_status) if rows else (None, None)
        if first_status is None:
            first_status = status
        if not isinstance(data, list):
            data = data.get("data") or data.get("history") or []
        if not data:
            break
        rows.extend(data)
        offset += limit
        if len(data) < limit:
            break
        time.sleep(0.3)
    return rows, first_status


def num(x):
    try:
        return float(x)
    except (TypeError, ValueError):
        return 0.0


def usdc_value(row):
    """Read USDC value softly: usdcSize else size*price."""
    if row.get("usdcSize") is not None:
        return num(row.get("usdcSize"))
    return num(row.get("size")) * num(row.get("price"))


def classify(row):
    """Canonical action. /activity uses type=TRADE + side=BUY|SELL; REDEEM/REWARD via type."""
    t = (row.get("type") or row.get("activityType") or "").upper()
    side = (row.get("side") or "").upper()
    if t == "TRADE":
        return side or "TRADE"  # BUY / SELL
    if t == "":
        # /trades fallback rows carry the direction directly on `side`
        return side or "UNKNOWN"
    return t  # REDEEM / REWARD / SPLIT / MERGE / CONVERSION / ...


def main():
    print(f"Fetching activity for {ADDR}\n")
    rows, status = fetch_all("/activity")

    if rows is None and status == 404:
        print(f"/activity returned HTTP {status} (not found). Trying /trades ...\n")
        rows, status = fetch_all("/trades")
        if rows is None:
            print(f"/trades also failed (HTTP {status}).")
            print("Other endpoints to try on data-api.polymarket.com:")
            for ep in ["/positions", "/value", "/holders", "/activity", "/trades"]:
                print(f"  {ep}?user=<addr>")
            return

    if rows is None:
        print(f"/activity failed persistently (HTTP {status}) after retries. "
              "Likely rate-limited — re-run in a moment.")
        return

    print(f"Total rows fetched: {len(rows)}\n")
    if not rows:
        print("No rows returned.")
        return

    # 2. Print keys of the first row
    print("=== Keys of first row ===")
    for k, v in rows[0].items():
        print(f"  {k}: {v!r}")
    print()

    # 3. Sum USDC by activity type
    by_type_count = defaultdict(int)
    by_type_usdc = defaultdict(float)

    buys = sells = redeems = rewards = 0.0

    # 5. Win rate by conditionId: net cash per market
    net_by_condition = defaultdict(float)

    for r in rows:
        t = classify(r)
        val = usdc_value(r)
        by_type_count[t] += 1
        by_type_usdc[t] += val

        cond = r.get("conditionId") or r.get("market") or r.get("conditionID") or "?"

        if t == "BUY":
            buys += val
            net_by_condition[cond] -= val
        elif t == "SELL":
            sells += val
            net_by_condition[cond] += val
        elif t == "REDEEM":
            redeems += val
            net_by_condition[cond] += val
        elif "REWARD" in t or "REBATE" in t:  # REWARD / MAKER_REBATE / REFERRAL_REWARD
            rewards += val
            # rewards tracked separately, not folded into per-market trading net

    # Breakdown by type
    print("=== Breakdown by activity type ===")
    for t in sorted(by_type_usdc, key=lambda k: -by_type_usdc[k]):
        print(f"  {t:12s} count={by_type_count[t]:5d}  usdc={by_type_usdc[t]:14.2f}")
    print()

    # 4. Cash flow totals
    net = sells + redeems - buys
    net_with_rewards = net + rewards
    print("=== Cash flow totals (USDC) ===")
    print(f"  Spent on BUY : {buys:14.2f}")
    print(f"  From SELL    : {sells:14.2f}")
    print(f"  From REDEEM  : {redeems:14.2f}")
    print(f"  From REWARD  : {rewards:14.2f}")
    print(f"  Net P&L (sells + redeems - buys)      : {net:14.2f}")
    print(f"  Net P&L incl. rewards                 : {net_with_rewards:14.2f}")
    print()

    # 5. Win rate
    markets = [c for c in net_by_condition if c != "?"]
    wins = sum(1 for c in markets if net_by_condition[c] > 0)
    total_markets = len(markets)
    wr = (wins / total_markets * 100) if total_markets else 0.0
    print("=== Win rate (by conditionId, net cash > 0 = win) ===")
    print(f"  Markets traded : {total_markets}")
    print(f"  Wins           : {wins}")
    print(f"  Win rate       : {wr:.1f}%")


if __name__ == "__main__":
    main()
