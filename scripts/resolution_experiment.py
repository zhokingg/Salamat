#!/usr/bin/env python3
"""Measure what one photo recognition costs, and where quality breaks.

Runs every photo in a folder through the deployed `recognize-food` Edge
Function at a ladder of long-side resolutions, and records the real token
usage, the model's answer and the latency for each run.

    python3 scripts/resolution_experiment.py --photos ./photos
    python3 scripts/resolution_experiment.py --photos ./photos --only 1024 \
        --label haiku      # second axis, after redeploying with another model

Ground truth
    If `ground_truth.csv` sits next to the photos it is used as the reference:
        filename,dish,portion_g
    Without it every resolution is scored against its own 1568 run instead,
    which measures *degradation*, not correctness. The summary says which
    mode was used.

Token accounting
    Real counts come from the `_usage` block the function returns. That block
    only exists once the updated function is deployed; until then the script
    falls back to Anthropic's documented image cost (w*h/750, with the long
    side clamped to 1568 server-side) and marks those rows `estimated`.
    Estimated and measured rows are never averaged together.

Nothing is written anywhere but the output CSV. No photo is uploaded anywhere
except the same endpoint the app already uses.
"""

from __future__ import annotations

import argparse
import base64
import csv
import io
import json
import os
import re
import statistics
import sys
import time
import urllib.error
import urllib.request
from dataclasses import dataclass, field, asdict
from pathlib import Path

try:
    from PIL import Image
except ImportError:
    sys.exit("Pillow is required:  python3 -m pip install pillow")

# Long sides to sweep, largest first so the 1568 reference exists before the
# smaller runs are compared against it.
LADDER = [1568, 1024, 768, 512, 384]

# Anthropic clamps the long side of an image to this before tokenising.
API_MAX_LONG_SIDE = 1568

# Documented image cost: one token per 750 pixels.
PIXELS_PER_TOKEN = 750

DEFAULT_FUNCTION = "recognize-food"
CONFIG_DART = Path("lib/config/supabase_config.dart")


# ─────────────────────────────── config ────────────────────────────────


def read_supabase_config() -> tuple[str, str]:
    """Pull the project URL and the public anon key out of the client config.

    The anon key is public by design (RLS is what protects data), which is why
    it can be read from the repo instead of being passed in. Overridable with
    SUPABASE_URL / SUPABASE_ANON_KEY for a different project.
    """
    url = os.environ.get("SUPABASE_URL")
    key = os.environ.get("SUPABASE_ANON_KEY")
    if url and key:
        return url.rstrip("/"), key
    if not CONFIG_DART.exists():
        sys.exit(
            f"{CONFIG_DART} not found — run from the repo root, or set "
            "SUPABASE_URL and SUPABASE_ANON_KEY."
        )
    src = CONFIG_DART.read_text(encoding="utf-8")

    def grab(after: str) -> str | None:
        # defaultValue follows the fromEnvironment name, so anchor on it.
        m = re.search(
            re.escape(after) + r".*?defaultValue:\s*\n?\s*'([^']+)'",
            src,
            re.S,
        )
        return m.group(1) if m else None

    url = url or grab("'SUPABASE_URL'")
    key = key or grab("'SUPABASE_ANON_KEY'")
    if not url or not key:
        sys.exit(f"could not parse url/anon key out of {CONFIG_DART}")
    return url.rstrip("/"), key


def anon_session(url: str, anon_key: str) -> str:
    """Sign in anonymously, exactly as the app does at bootstrap."""
    req = urllib.request.Request(
        f"{url}/auth/v1/signup",
        data=b"{}",
        headers={"apikey": anon_key, "content-type": "application/json"},
        method="POST",
    )
    with urllib.request.urlopen(req, timeout=30) as res:
        body = json.load(res)
    token = body.get("access_token")
    if not token:
        sys.exit(f"anonymous sign-in failed: {json.dumps(body)[:300]}")
    return token


# ──────────────────────────────── images ───────────────────────────────


def resize_to_long_side(path: Path, long_side: int, quality: int) -> tuple[bytes, int, int]:
    """Downscale so the longest edge is `long_side`, re-encode as JPEG.

    EXIF orientation is applied first, otherwise a portrait phone photo would
    be measured with its axes swapped. Never upscales: a source smaller than
    the target is encoded as-is and its true size reported, so the row is not
    silently mislabelled.
    """
    with Image.open(path) as im:
        try:
            from PIL import ImageOps

            im = ImageOps.exif_transpose(im)
        except Exception:
            pass
        im = im.convert("RGB")
        w, h = im.size
        scale = long_side / max(w, h)
        if scale < 1.0:
            im = im.resize(
                (max(1, round(w * scale)), max(1, round(h * scale))),
                Image.LANCZOS,
            )
        buf = io.BytesIO()
        im.save(buf, "JPEG", quality=quality, optimize=True)
        return buf.getvalue(), im.size[0], im.size[1]


def estimated_input_tokens(w: int, h: int) -> int:
    """Anthropic's documented image cost, after the server-side clamp.

    Also covers the system prompt at a flat ~180 tokens, measured from the
    prompt text in the function (Russian, ~120 words). Marked `estimated` in
    the CSV so it is never mistaken for a metered number.
    """
    scale = min(1.0, API_MAX_LONG_SIDE / max(w, h))
    cw, ch = round(w * scale), round(h * scale)
    return round(cw * ch / PIXELS_PER_TOKEN) + 180


# ───────────────────────────────── run ─────────────────────────────────


@dataclass
class Run:
    photo: str
    long_side: int
    sent_width: int
    sent_height: int
    request_bytes: int
    http_status: int
    ok: bool
    error: str = ""
    name: str = ""
    kcal_per_100g: float | None = None
    portion_g: float | None = None
    kcal_portion: float | None = None
    confidence: float | None = None
    input_tokens: int | None = None
    output_tokens: int | None = None
    tokens_source: str = ""
    model: str = ""
    duration_ms: int = 0
    request_id: str = ""


def call_function(
    url: str,
    anon_key: str,
    token: str,
    fn: str,
    jpeg: bytes,
    timeout: int,
) -> tuple[int, dict, int]:
    b64 = base64.b64encode(jpeg).decode("ascii")
    payload = json.dumps({"imageBase64": b64, "mediaType": "image/jpeg"}).encode()
    req = urllib.request.Request(
        f"{url}/functions/v1/{fn}",
        data=payload,
        headers={
            "apikey": anon_key,
            "Authorization": f"Bearer {token}",
            "content-type": "application/json",
        },
        method="POST",
    )
    t0 = time.monotonic()
    try:
        with urllib.request.urlopen(req, timeout=timeout) as res:
            body = json.load(res)
            status = res.status
    except urllib.error.HTTPError as e:
        raw = e.read().decode("utf-8", "replace")
        try:
            body = json.loads(raw)
        except Exception:
            body = {"error": raw[:200]}
        status = e.code
    except Exception as e:  # network, timeout, ...
        body = {"error": f"{type(e).__name__}: {e}"}
        status = 0
    return status, body, round((time.monotonic() - t0) * 1000)


def do_run(cfg, photo: Path, long_side: int) -> Run:
    jpeg, w, h = resize_to_long_side(photo, long_side, cfg.quality)
    status, body, ms = call_function(
        cfg.url, cfg.anon, cfg.token, cfg.function, jpeg, cfg.timeout
    )
    r = Run(
        photo=photo.name,
        long_side=long_side,
        sent_width=w,
        sent_height=h,
        # Base64 length is what actually crosses the wire.
        request_bytes=len(base64.b64encode(jpeg)),
        http_status=status,
        ok=False,
        duration_ms=ms,
    )
    if status != 200:
        r.error = str(body.get("error", ""))[:160]
        return r

    usage = body.get("_usage") or {}
    meta = body.get("_meta") or {}
    if usage.get("input_tokens") is not None:
        r.input_tokens = usage.get("input_tokens")
        r.output_tokens = usage.get("output_tokens")
        r.tokens_source = "measured"
    else:
        # Updated function not deployed yet.
        r.input_tokens = estimated_input_tokens(w, h)
        r.output_tokens = None
        r.tokens_source = "estimated"
    r.model = meta.get("model", "")
    r.request_id = meta.get("request_id", "")

    def num(key):
        v = body.get(key)
        return float(v) if isinstance(v, (int, float)) else None

    r.name = str(body.get("name", "")).strip()
    r.kcal_per_100g = num("calories_per_100g")
    r.portion_g = num("portion_g")
    r.confidence = num("confidence")
    if r.kcal_per_100g is not None and r.portion_g is not None:
        r.kcal_portion = round(r.kcal_per_100g * r.portion_g / 100, 1)
    # confidence 0 is the function's documented "could not identify" answer.
    r.ok = bool(r.name) and (r.confidence or 0) > 0
    return r


# ─────────────────────────────── scoring ───────────────────────────────


def norm_dish(s: str) -> str:
    s = (s or "").lower().strip()
    s = re.sub(r"[^\w\s]", " ", s, flags=re.UNICODE)
    return re.sub(r"\s+", " ", s)


def dish_matches(got: str, want: str) -> bool:
    """Loose containment match on normalised words.

    The model answers in free-form Russian ("Плов узбекский с бараниной"), so
    an exact string compare would score a correct answer as wrong. A match is
    any shared content word of 4+ characters.
    """
    g, w = norm_dish(got), norm_dish(want)
    if not g or not w:
        return False
    if g == w or w in g or g in w:
        return True
    gw = {t for t in g.split() if len(t) >= 4}
    ww = {t for t in w.split() if len(t) >= 4}
    return bool(gw & ww)


def load_ground_truth(photos_dir: Path) -> dict[str, dict]:
    p = photos_dir / "ground_truth.csv"
    if not p.exists():
        p = photos_dir.parent / "ground_truth.csv"
    if not p.exists():
        return {}
    out = {}
    with p.open(encoding="utf-8-sig", newline="") as f:
        for row in csv.DictReader(f):
            keys = {k.lower().strip(): (v or "").strip() for k, v in row.items() if k}
            fn = keys.get("filename") or keys.get("file") or keys.get("name")
            if not fn:
                continue
            portion = keys.get("portion_g") or keys.get("portion") or ""
            try:
                portion_v = float(portion) if portion else None
            except ValueError:
                portion_v = None
            out[fn] = {
                "dish": keys.get("dish") or keys.get("real_name") or "",
                "portion_g": portion_v,
            }
    return out


def mean(xs):
    xs = [x for x in xs if x is not None]
    return statistics.fmean(xs) if xs else None


def summarise(runs: list[Run], truth: dict[str, dict]) -> list[dict]:
    by_ls: dict[int, list[Run]] = {}
    for r in runs:
        by_ls.setdefault(r.long_side, []).append(r)

    # Reference for degradation scoring: the 1568 run of the same photo.
    ref = {r.photo: r for r in by_ls.get(max(LADDER), []) if r.ok}

    rows = []
    for ls in sorted(by_ls, reverse=True):
        group = by_ls[ls]
        good = [r for r in group if r.ok]
        measured = [r for r in group if r.tokens_source == "measured"]
        estimated = [r for r in group if r.tokens_source == "estimated"]

        # Accuracy against ground truth if we have it, else agreement with 1568.
        if truth:
            scored = [r for r in good if r.photo in truth]
            hits = sum(1 for r in scored if dish_matches(r.name, truth[r.photo]["dish"]))
            acc = hits / len(scored) if scored else None
            acc_basis = f"ground truth (n={len(scored)})"
            portion_err = mean([
                abs(r.portion_g - truth[r.photo]["portion_g"])
                for r in scored
                if r.portion_g is not None
                and truth[r.photo]["portion_g"] is not None
            ])
        else:
            scored = [r for r in good if r.photo in ref]
            hits = sum(1 for r in scored if dish_matches(r.name, ref[r.photo].name))
            acc = hits / len(scored) if scored else None
            acc_basis = f"agreement with 1568 (n={len(scored)})"
            portion_err = mean([
                abs(r.portion_g - ref[r.photo].portion_g)
                for r in scored
                if r.portion_g is not None and ref[r.photo].portion_g is not None
            ])

        # Calorie error is always relative to 1568, per the brief.
        kcal_err = mean([
            abs(r.kcal_portion - ref[r.photo].kcal_portion)
            for r in good
            if r.photo in ref
            and r.kcal_portion is not None
            and ref[r.photo].kcal_portion is not None
        ])
        kcal_err_pct = mean([
            abs(r.kcal_portion - ref[r.photo].kcal_portion)
            / ref[r.photo].kcal_portion * 100
            for r in good
            if r.photo in ref
            and r.kcal_portion is not None
            and ref[r.photo].kcal_portion
        ])

        rows.append({
            "long_side": ls,
            "calls": len(group),
            "recognised": len(good),
            "avg_input_tokens": round(mean([r.input_tokens for r in group]) or 0),
            "avg_output_tokens": (
                round(mean([r.output_tokens for r in measured]) or 0)
                if measured else None
            ),
            "tokens_measured": len(measured),
            "tokens_estimated": len(estimated),
            "avg_request_kb": round((mean([r.request_bytes for r in group]) or 0) / 1024, 1),
            "accuracy": None if acc is None else round(acc * 100, 1),
            "accuracy_basis": acc_basis,
            "kcal_mae_vs_1568": None if kcal_err is None else round(kcal_err, 1),
            "kcal_mape_vs_1568": None if kcal_err_pct is None else round(kcal_err_pct, 1),
            "portion_mae": None if portion_err is None else round(portion_err, 1),
            "avg_ms": round(mean([r.duration_ms for r in group]) or 0),
            "avg_confidence": (
                round(mean([r.confidence for r in good]) or 0, 3) if good else None
            ),
        })
    return rows


def fragile_dishes(
    runs: list[Run], truth: dict[str, dict]
) -> tuple[list[tuple[str, int]], list[str]]:
    """Split the set into dishes that degrade and dishes that never worked.

    `degrades` is the interesting list: the highest resolution at which the
    answer already stops matching. Visually ambiguous dishes (plov vs plain
    rice) flip well before the rest of the set, and those are the ones a
    downscale decision hinges on.

    `wrong_at_top` is kept separate: a photo the model gets wrong even at 1568
    says nothing about resolution, and folding it into the degradation list
    would overstate the cost of downscaling.
    """
    top = max(LADDER)
    ref = {r.photo: r for r in runs if r.long_side == top and r.ok}
    degrades: list[tuple[str, int]] = []
    wrong_at_top: list[str] = []

    for photo, r0 in ref.items():
        want = truth.get(photo, {}).get("dish") or r0.name
        if truth and not dish_matches(r0.name, want):
            wrong_at_top.append(photo)
            continue
        breaks_at = None
        # Walk down; the first resolution that disagrees is where it breaks.
        for ls in sorted(LADDER, reverse=True):
            got = next(
                (r for r in runs if r.photo == photo and r.long_side == ls), None
            )
            if got is None or ls == top:
                continue
            if not got.ok or not dish_matches(got.name, want):
                breaks_at = ls
                break
        if breaks_at is not None:
            degrades.append((photo, breaks_at))
    # Highest breaking resolution first — the most fragile.
    return sorted(degrades, key=lambda t: -t[1]), sorted(wrong_at_top)


# ───────────────────────────────── main ────────────────────────────────


@dataclass
class Cfg:
    url: str
    anon: str
    token: str
    function: str
    quality: int
    timeout: int


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--photos", required=True, type=Path,
                    help="folder of photos (jpg/jpeg/png/heic-converted)")
    ap.add_argument("--out", type=Path, default=Path("scripts/out"),
                    help="where the CSV and summary land")
    ap.add_argument("--only", type=int, nargs="*", default=None,
                    help=f"subset of the ladder, default {LADDER}")
    ap.add_argument("--label", default="",
                    help="tag for this run, e.g. the model under test")
    ap.add_argument("--quality", type=int, default=85,
                    help="JPEG quality for the re-encode (default 85)")
    ap.add_argument("--timeout", type=int, default=120)
    ap.add_argument("--limit", type=int, default=0,
                    help="only the first N photos (smoke test)")
    ap.add_argument("--sleep", type=float, default=0.4,
                    help="pause between calls, to stay polite to the API")
    ap.add_argument("--function", default=DEFAULT_FUNCTION)
    args = ap.parse_args()

    ladder = args.only or LADDER
    if max(LADDER) not in ladder:
        print(f"note: {max(LADDER)} not in the ladder — "
              "degradation columns relative to it will be empty")

    photos = sorted(
        p for p in args.photos.iterdir()
        if p.suffix.lower() in {".jpg", ".jpeg", ".png", ".webp"}
        and not p.name.startswith(".")
    ) if args.photos.is_dir() else []
    if not photos:
        sys.exit(f"no photos found in {args.photos}")
    if args.limit:
        photos = photos[: args.limit]

    truth = load_ground_truth(args.photos)
    url, anon = read_supabase_config()
    token = anon_session(url, anon)
    cfg = Cfg(url, anon, token, args.function, args.quality, args.timeout)

    print(f"project   {url}")
    print(f"photos    {len(photos)}  from {args.photos}")
    print(f"ladder    {ladder}")
    print(f"truth     {'ground_truth.csv (' + str(len(truth)) + ' rows)' if truth else 'ABSENT — scoring against 1568'}")
    print()

    runs: list[Run] = []
    total = len(photos) * len(ladder)
    n = 0
    for photo in photos:
        for ls in ladder:
            n += 1
            r = do_run(cfg, photo, ls)
            runs.append(r)
            flag = "ok " if r.ok else ("ERR" if r.http_status != 200 else "no-id")
            print(
                f"[{n:>3}/{total}] {flag} {photo.name[:26]:26s} {ls:>4}px "
                f"{r.sent_width}x{r.sent_height:<5} "
                f"{r.request_bytes/1024:6.1f}kB "
                f"in={r.input_tokens or '-':>5} out={r.output_tokens or '-':>4} "
                f"{r.duration_ms:>5}ms  {r.name[:24]}"
                + (f"  <{r.error[:40]}>" if r.error else "")
            )
            time.sleep(args.sleep)

    args.out.mkdir(parents=True, exist_ok=True)
    tag = f"_{args.label}" if args.label else ""
    csv_path = args.out / f"runs{tag}.csv"
    with csv_path.open("w", encoding="utf-8", newline="") as f:
        w = csv.DictWriter(f, fieldnames=list(asdict(runs[0]).keys()))
        w.writeheader()
        for r in runs:
            w.writerow(asdict(r))

    rows = summarise(runs, truth)
    sum_path = args.out / f"summary{tag}.csv"
    with sum_path.open("w", encoding="utf-8", newline="") as f:
        w = csv.DictWriter(f, fieldnames=list(rows[0].keys()))
        w.writeheader()
        w.writerows(rows)

    print()
    print(f"sample: {len(photos)} photos x {len(ladder)} resolutions = {len(runs)} calls")
    if len(photos) < 30:
        print(f"WARNING: {len(photos)} photos is too few for a conclusion — "
              "treat every number below as indicative only.")
    if not truth:
        print("WARNING: no ground_truth.csv — 'accuracy' is agreement with the "
              "1568 answer, which cannot detect an error 1568 also makes.")
    est = sum(r.tokens_source == "estimated" for r in runs)
    if est:
        print(f"WARNING: {est}/{len(runs)} rows have ESTIMATED tokens "
              "(deploy the updated function for metered counts).")
    print()

    hdr = (f"{'long':>5} {'calls':>5} {'recog':>5} {'in_tok':>7} {'out_tok':>7} "
           f"{'req_kB':>7} {'acc%':>6} {'kcal_MAE':>9} {'kcal%':>6} {'ms':>6}")
    print(hdr)
    print("-" * len(hdr))
    for r in rows:
        print(f"{r['long_side']:>5} {r['calls']:>5} {r['recognised']:>5} "
              f"{r['avg_input_tokens']:>7} "
              f"{(r['avg_output_tokens'] if r['avg_output_tokens'] is not None else '-'):>7} "
              f"{r['avg_request_kb']:>7} "
              f"{(r['accuracy'] if r['accuracy'] is not None else '-'):>6} "
              f"{(r['kcal_mae_vs_1568'] if r['kcal_mae_vs_1568'] is not None else '-'):>9} "
              f"{(r['kcal_mape_vs_1568'] if r['kcal_mape_vs_1568'] is not None else '-'):>6} "
              f"{r['avg_ms']:>6}")

    degrades, wrong_at_top = fragile_dishes(runs, truth)
    if degrades:
        print()
        print("degrades earliest (highest resolution where the answer already differs):")
        for photo, ls in degrades[:12]:
            print(f"  {ls:>4}px  {photo}")
    if wrong_at_top:
        print()
        print(f"wrong even at {max(LADDER)}px — a model miss, not a resolution "
              "problem, excluded from the list above:")
        for photo in wrong_at_top[:12]:
            print(f"        {photo}")

    print()
    print(f"wrote {csv_path}")
    print(f"wrote {sum_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
