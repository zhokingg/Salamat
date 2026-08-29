#!/usr/bin/env python3
"""Find sibling bots of PBot-6 by scanning the markets it trades and harvesting
   holder/trader names, looking for the PBot-* series and frequent co-occurrents."""

import re
import time
import json
from collections import Counter, defaultdict
from urllib.request import urlopen, Request
from urllib.error import HTTPError

import poly_pnl as P

SELF = P.ADDR.lower()
BASE = "https://data-api.polymarket.com"


def get(path):
    url = f"{BASE}{path}"
    try:
        req = Request(url, headers={"User-Agent": "Mozilla/5.0"})
        with urlopen(req, timeout=30) as r:
            return json.loads(r.read().decode())
    except HTTPError:
        return None
    except Exception:
        return None


def main():
    rows, _ = P.fetch_all("/activity")
    conds = []
    seen = set()
    for r in rows:
        c = r.get("conditionId")
        if c and c not in seen:
            seen.add(c)
            conds.append(c)
    print(f"PBot-6 traded {len(conds)} distinct markets; scanning holders of a sample...")

    sample = conds[:120]
    name_to_wallets = defaultdict(set)
    wallet_to_name = {}
    cooccur = Counter()       # wallets that hold the same markets as PBot-6
    pbots = {}                # name -> wallet for PBot-* series

    for i, c in enumerate(sample):
        data = get(f"/holders?market={c}&limit=100")
        if not data:
            continue
        market_wallets = set()
        for tok in data:
            for h in tok.get("holders", []):
                w = (h.get("proxyWallet") or "").lower()
                n = h.get("name") or ""
                if not w:
                    continue
                wallet_to_name[w] = n
                name_to_wallets[n].add(w)
                market_wallets.add(w)
                if re.match(r"(?i)^p?bot[-_ ]?\d+$", n.strip()):
                    pbots[n] = w
        for w in market_wallets:
            if w != SELF:
                cooccur[w] += 1
        if (i + 1) % 30 == 0:
            print(f"  scanned {i + 1}/{len(sample)} markets...")
        time.sleep(0.15)

    print("\n=== PBot-* / Bot-N series found ===")
    if pbots:
        for n in sorted(pbots):
            print(f"  {n:12s} {pbots[n]}")
    else:
        print("  (none by exact 'PBot-N' name in holders sample)")

    # Names that look bot-like
    print("\n=== Names containing 'bot' ===")
    botnames = sorted({n for n in name_to_wallets if "bot" in n.lower()})
    for n in botnames[:40]:
        for w in name_to_wallets[n]:
            print(f"  {n:20s} {w}")

    print("\n=== Wallets co-holding the most of PBot-6's markets (excl. self) ===")
    for w, k in cooccur.most_common(25):
        print(f"  {k:4d}/{len(sample)}  {w}  {wallet_to_name.get(w,'')!r}")


if __name__ == "__main__":
    main()
