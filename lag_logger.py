#!/usr/bin/env python3
import argparse, csv, json, sys, threading, time

class State:
    def __init__(self):
        self.lock = threading.Lock()
        self.binance_px = None; self.binance_ts = 0
        self.chainlink_px = None; self.chainlink_ts = 0
        self.book_mid = None; self.book_ts = 0
        self.events = []; self.run = True
    def now(self): return time.monotonic() * 1000.0

def binance_thread(st):
    import websocket
    url = "wss://stream.binance.com:9443/ws/btcusdt@trade"
    def on_msg(ws, msg):
        try:
            d = json.loads(msg); px = float(d["p"])
            with st.lock: st.binance_px = px; st.binance_ts = st.now()
        except Exception: pass
    while st.run:
        try:
            ws = websocket.WebSocketApp(url, on_message=on_msg)
            ws.run_forever(ping_interval=20)
        except Exception as e: print(f"[binance] {e}", file=sys.stderr)
        time.sleep(2)

def chainlink_thread(st, rpc, feed, poll_ms=300):
    import requests
    def latest_price():
        payload = {"jsonrpc":"2.0","id":1,"method":"eth_call",
                   "params":[{"to":feed,"data":"0xfeaf968c"},"latest"]}
        try:
            r = requests.post(rpc, json=payload, timeout=5)
            res = r.json().get("result")
            if not res: return None
            raw = res[2:]; ans = int(raw[64:128], 16)
            if ans >= 2**255: ans -= 2**256
            return ans / 1e8
        except Exception: return None
    while st.run:
        px = latest_price()
        if px:
            with st.lock: st.chainlink_px = px; st.chainlink_ts = st.now()
        time.sleep(poll_ms/1000)

def polymarket_thread(st, token_id):
    import websocket
    url = "wss://ws-subscriptions-clob.polymarket.com/ws/market"
    def on_open(ws): ws.send(json.dumps({"assets_ids":[token_id], "type":"market"}))
    def on_msg(ws, msg):
        try:
            data = json.loads(msg)
            rows = data if isinstance(data, list) else [data]
            for d in rows:
                bids = d.get("bids") or d.get("buys") or []
                asks = d.get("asks") or d.get("sells") or []
                def px(side):
                    if not side: return None
                    p = side[0].get("price") if isinstance(side[0], dict) else side[0][0]
                    return float(p)
                b, a = px(bids), px(asks)
                mid = (b + a)/2 if (b is not None and a is not None) else (b or a)
                if mid is not None:
                    with st.lock: st.book_mid = mid; st.book_ts = st.now()
        except Exception: pass
    while st.run:
        try:
            ws = websocket.WebSocketApp(url, on_open=on_open, on_message=on_msg)
            ws.run_forever(ping_interval=20)
        except Exception as e: print(f"[polymarket] {e}", file=sys.stderr)
        time.sleep(2)

def measure_loop(st, move_thr, reprice_thr, source, timeout_ms=5000):
    last_src = None; armed_ts = None; armed_dir = 0; armed_book = None
    while st.run:
        with st.lock:
            src_px = st.binance_px if source == "binance" else st.chainlink_px
            book = st.book_mid; now = st.now()
        if src_px is None or book is None: time.sleep(0.005); continue
        if last_src is None: last_src = src_px; time.sleep(0.005); continue
        if armed_ts is None:
            move = src_px - last_src
            if abs(move) >= move_thr:
                armed_ts = now; armed_dir = 1 if move > 0 else -1; armed_book = book
        else:
            book_move = book - armed_book
            if abs(book_move) >= reprice_thr:
                delay = now - armed_ts
                ok = (book_move > 0) == (armed_dir > 0)
                st.events.append({"source":source,"src_move_usd":round(src_px-last_src,2),
                    "reprice_delay_ms":round(delay,1),"book_move":round(book_move,4),"aligned":int(ok)})
                print(f"  [{source}] price moved -> book repriced after {delay:6.0f} ms  (dir {'OK' if ok else 'opp'})")
                armed_ts = None; last_src = src_px
            elif now - armed_ts > timeout_ms:
                st.events.append({"source":source,"src_move_usd":round(src_px-last_src,2),
                    "reprice_delay_ms":-1,"book_move":0.0,"aligned":0})
                armed_ts = None; last_src = src_px
        time.sleep(0.005)

def summarize(st):
    ev = [e for e in st.events if e["reprice_delay_ms"] >= 0]
    print("\n" + "="*60)
    print("RESULT - how long after a price move does the book reprice?")
    print("="*60)
    if not ev:
        print("No reprice events captured. Try a busier period / lower")
        print("--move-threshold, or check the token id / connections.")
        return
    delays = sorted(e["reprice_delay_ms"] for e in ev); n = len(delays)
    def pct(p): return delays[min(n-1, int(p*n))]
    print(f"Reprice events captured : {n}")
    print(f"Median delay            : {pct(0.50):.0f} ms")
    print(f"25th percentile (fast)  : {pct(0.25):.0f} ms")
    print(f"75th percentile (slow)  : {pct(0.75):.0f} ms")
    print(f"Fastest                 : {delays[0]:.0f} ms")
    print("-"*60)
    print("WHAT THIS MEANS:")
    print(f"  Your opportunity window is ~{pct(0.50):.0f} ms (median).")
    print("  Your full path (detect+decide+order lands+fills) must beat this.")
    print("  Polymarket is on-chain, so fills are often HUNDREDS of ms.")
    print("="*60)

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--token-id", required=False)
    ap.add_argument("--minutes", type=float, default=30)
    ap.add_argument("--source", choices=["binance","chainlink"], default="binance")
    ap.add_argument("--rpc", default="https://polygon-rpc.com")
    ap.add_argument("--feed", default="0xc907E116054Ad103354f2D350FD2514433D57F6f")
    ap.add_argument("--move-threshold", type=float, default=5.0)
    ap.add_argument("--reprice-threshold", type=float, default=0.005)
    ap.add_argument("--out", default="lag_events.csv")
    args = ap.parse_args()
    if not args.token_id:
        print("Need --token-id. Get it from gamma-api.polymarket.com/markets?slug=<slug>")
        return
    st = State()
    threads = [threading.Thread(target=binance_thread, args=(st,), daemon=True),
               threading.Thread(target=polymarket_thread, args=(st, args.token_id), daemon=True)]
    if args.source == "chainlink":
        threads.append(threading.Thread(target=chainlink_thread, args=(st, args.rpc, args.feed), daemon=True))
    threads.append(threading.Thread(target=measure_loop,
        args=(st, args.move_threshold, args.reprice_threshold, args.source), daemon=True))
    for t in threads: t.start()
    print(f"Logging for {args.minutes} min. Source={args.source}. Watching...\n")
    try: time.sleep(args.minutes * 60)
    except KeyboardInterrupt: pass
    st.run = False; time.sleep(0.3)
    with open(args.out, "w", newline="") as f:
        if st.events:
            w = csv.DictWriter(f, fieldnames=list(st.events[0].keys()))
            w.writeheader(); w.writerows(st.events)
    print(f"\nWrote {len(st.events)} events -> {args.out}")
    summarize(st)

if __name__ == "__main__":
    main()
