#!/usr/bin/env python3
"""Probe Polymarket gamma API: how many BTC up/down markets exist, and what
   durations (5m / 15m / 1h / 4h). Read-only, no key. We page closed markets
   tagged crypto and bucket by the open->close span parsed from timestamps."""

import json
import time
from urllib.request import urlopen, Request
from urllib.error import HTTPError, URLError
from datetime import datetime, timezone

GAMMA = "https://gamma-api.polymarket.com"


def http_json(url):
    for attempt in range(4):
        try:
            req = Request(url, headers={"User-Agent": "Mozilla/5.0"})
            with urlopen(req, timeout=30) as r:
                return json.loads(r.read().decode())
        except (HTTPError, URLError) as e:
            time.sleep(0.5 * (attempt + 1))
            last = e
    raise last


def parse_ts(s):
    if not s:
        return None
    try:
        return datetime.fromisoformat(s.replace("Z", "+00:00"))
    except Exception:
        return None


def main():
    # Search markets by crypto/bitcoin keyword. Gamma supports limit/offset.
    durations = {}   # rounded-minutes -> count
    btc_hits = 0
    sample = []
    offset = 0
    LIMIT = 100
    pages = 0
    while pages < 120:
        url = (f"{GAMMA}/markets?closed=true&limit={LIMIT}&offset={offset}"
               f"&order=startDate&ascending=false")
        data = http_json(url)
        if not data:
            break
        pages += 1
        for m in data:
            q = (m.get("question") or "").lower()
            slug = (m.get("slug") or "").lower()
            blob = q + " " + slug
            is_btc = ("btc" in blob or "bitcoin" in blob)
            is_updown = ("up or down" in blob or "updown" in blob
                         or ("up" in blob and "down" in blob))
            if not (is_btc and is_updown):
                continue
            btc_hits += 1
            o = parse_ts(m.get("startDate") or m.get("startDateIso"))
            c = parse_ts(m.get("endDate") or m.get("endDateIso"))
            dur_min = None
            if o and c:
                dur_min = round((c - o).total_seconds() / 60)
            durations[dur_min] = durations.get(dur_min, 0) + 1
            if len(sample) < 8:
                sample.append({
                    "q": m.get("question"),
                    "slug": m.get("slug"),
                    "dur_min": dur_min,
                    "start": m.get("startDate"),
                    "end": m.get("endDate"),
                    "clobTokenIds": m.get("clobTokenIds"),
                    "outcomePrices": m.get("outcomePrices"),
                    "outcomes": m.get("outcomes"),
                })
        if len(data) < LIMIT:
            break
        offset += LIMIT
        time.sleep(0.1)

    print(f"pages scanned: {pages}, BTC up/down markets found: {btc_hits}\n")
    print("duration (minutes) -> count:")
    for d in sorted(durations, key=lambda x: (x is None, x)):
        print(f"  {str(d):>8} min : {durations[d]}")

    print("\n--- sample rows (keys we can use) ---")
    for s in sample:
        print(json.dumps(s, indent=2)[:600])
        print("-")


if __name__ == "__main__":
    main()
