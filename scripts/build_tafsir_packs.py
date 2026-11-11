#!/usr/bin/env python3
"""Builds the offline verse-meaning packs used by SARI's tafsir screen.

Source: QuranEnc (https://quranenc.com), the same service the app already relies on.
Run this on a computer with internet access, from the repository root:

    python3 scripts/build_tafsir_packs.py --out tafsir-packs

Then host the resulting folder over HTTPS (for example GitHub Pages) and set
SARI_TAFSIR_PACK_BASE_URL in project.yml to that address. Each language is written
to <out>/<code>/ as <code>.json plus manifest.json (SHA-256 is checked by the app).

Only languages whose QuranEnc translation key is filled in SOURCES are built.
Use --self-test to check the validation logic without any network access.
"""
import argparse
import hashlib
import json
import os
import sys
import tempfile
import time
import urllib.error
import urllib.request
from datetime import date

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
QURAN_JSON = os.path.join(ROOT, "SARI", "Resources", "data", "quran_tafseer.json")
API = "https://quranenc.com/api/v1/translation/sura/{key}/{sura}"
AYAH_COUNT = 6236

# App language code -> QuranEnc translation key.
# None means "not configured yet": the script skips that language.
# Check each key on https://quranenc.com before running; a wrong key fails the
# verse-count check below instead of producing a broken pack.
SOURCES = {
    "en": "english_hilali_khan",  # same source the app already uses
    "tr": None,
    "ms": None,
    "id": None,
    "ja": None,
    "zh": None,
    "ru": None,
    "fr": None,
}


def load_expected(path=QURAN_JSON):
    """Returns {sura: {aya: global_id}} from the app's bundled Quran data."""
    with open(path, encoding="utf-8") as f:
        ayat = json.load(f)
    expected = {}
    for a in ayat:
        expected.setdefault(int(a["sura"]), {})[int(a["ayah"])] = int(a["id"])
    if len(ayat) != AYAH_COUNT or len(expected) != 114:
        raise ValueError("quran_tafseer.json does not have 6236 ayat in 114 surahs")
    return expected


def fetch_surah(key, sura, attempts=3):
    """Returns the 'result' list for one surah, retrying on network or format errors."""
    url = API.format(key=key, sura=sura)
    last_error = None
    for attempt in range(1, attempts + 1):
        try:
            with urllib.request.urlopen(url, timeout=30) as response:
                payload = json.loads(response.read().decode("utf-8"))
            return payload["result"]
        except (urllib.error.URLError, TimeoutError, KeyError, ValueError) as error:
            last_error = error
            time.sleep(2 * attempt)
    raise RuntimeError(f"{key} surah {sura}: {last_error}")


def assemble(payloads, expected):
    """Checks every surah payload against the expected ids and returns sorted rows.

    payloads: {sura: [ {id, sura, aya, translation}, ... ]}
    Raises ValueError on any mismatch, so a bad source never produces a pack.
    """
    rows = {}
    for sura in range(1, 115):
        items = payloads.get(sura)
        verses = expected[sura]
        if items is None:
            raise ValueError(f"surah {sura} missing")
        if len(items) != len(verses):
            raise ValueError(f"surah {sura}: expected {len(verses)} verses, got {len(items)}")
        seen = set()
        for item in items:
            if int(item["sura"]) != sura:
                raise ValueError(f"surah {sura}: verse tagged with surah {item['sura']}")
            aya = int(item["aya"])
            global_id = int(item["id"])
            if verses.get(aya) != global_id:
                raise ValueError(f"surah {sura}: ayah {aya} has id {global_id}, expected {verses.get(aya)}")
            if aya in seen:
                raise ValueError(f"surah {sura}: ayah {aya} appears twice")
            seen.add(aya)
            text = " ".join(str(item.get("translation", "")).split())
            if not text:
                raise ValueError(f"surah {sura}: ayah {aya} has empty text")
            rows[global_id] = text
    if len(rows) != AYAH_COUNT or set(rows) != set(range(1, AYAH_COUNT + 1)):
        raise ValueError("assembled ids are not exactly 1...6236")
    return [{"id": i, "text": rows[i]} for i in sorted(rows)]


def write_pack(out_dir, code, rows, source):
    """Writes <code>/<code>.json and <code>/manifest.json and returns the manifest."""
    pack_dir = os.path.join(out_dir, code)
    os.makedirs(pack_dir, exist_ok=True)
    data = json.dumps(rows, ensure_ascii=False, separators=(",", ":")).encode("utf-8")
    digest = hashlib.sha256(data).hexdigest()
    file_name = f"{code}.json"
    with open(os.path.join(pack_dir, file_name), "wb") as f:
        f.write(data)
    manifest = {
        "language": code,
        "version": date.today().isoformat(),
        "entries": AYAH_COUNT,
        "sha256": digest,
        "bytes": len(data),
        "file": file_name,
        "source": source,
    }
    with open(os.path.join(pack_dir, "manifest.json"), "w", encoding="utf-8") as f:
        json.dump(manifest, f, ensure_ascii=False, indent=2)
    return manifest


def build(out_dir, codes):
    expected = load_expected()
    failures = []
    for code in codes:
        key = SOURCES.get(code)
        if key is None:
            print(f"[skip] {code}: no QuranEnc key configured in SOURCES")
            continue
        print(f"[build] {code} <- {key}")
        try:
            payloads = {}
            for sura in range(1, 115):
                payloads[sura] = fetch_surah(key, sura)
                time.sleep(0.2)
            rows = assemble(payloads, expected)
            manifest = write_pack(out_dir, code, rows, f"QuranEnc / {key}")
            print(f"[ok] {code}: {manifest['entries']} entries, sha256 {manifest['sha256'][:12]}...")
        except (RuntimeError, ValueError) as error:
            failures.append(code)
            print(f"[fail] {code}: {error}", file=sys.stderr)
    return failures


def self_test():
    """Checks validation on real verse ids without network access."""
    expected = load_expected()
    fake = {}
    for sura, verses in expected.items():
        fake[sura] = [
            {"id": gid, "sura": sura, "aya": aya, "translation": f"meaning {gid}"}
            for aya, gid in verses.items()
        ]
    rows = assemble(fake, expected)
    assert len(rows) == AYAH_COUNT and rows[0] == {"id": 1, "text": "meaning 1"}

    broken = {k: list(v) for k, v in fake.items()}
    broken[2] = broken[2][:-1]
    try:
        assemble(broken, expected)
        raise AssertionError("missing verse was not detected")
    except ValueError:
        pass

    wrong_id = {k: list(v) for k, v in fake.items()}
    wrong_id[1][0] = dict(wrong_id[1][0], id=999)
    try:
        assemble(wrong_id, expected)
        raise AssertionError("wrong verse id was not detected")
    except ValueError:
        pass

    with tempfile.TemporaryDirectory() as tmp:
        manifest = write_pack(tmp, "xx", rows, "self-test")
        with open(os.path.join(tmp, "xx", "xx.json"), "rb") as f:
            assert hashlib.sha256(f.read()).hexdigest() == manifest["sha256"]
    print("self-test passed: 6236 verses assembled, bad inputs rejected, checksum matches")


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--out", default="tafsir-packs", help="output folder")
    parser.add_argument("--langs", nargs="*", default=list(SOURCES), help="language codes to build")
    parser.add_argument("--self-test", action="store_true", help="run offline checks only")
    args = parser.parse_args()

    if args.self_test:
        self_test()
        return 0

    failures = build(args.out, args.langs)
    if failures:
        print(f"Failed languages: {', '.join(failures)}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
