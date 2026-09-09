#!/usr/bin/env python3
"""Static release preflight for the SARI iOS project.

Runs without third-party Python packages so GitHub Actions can execute it before
XcodeGen/Xcode. It catches the resource-collision class that previously caused
xcodebuild exit 65, plus malformed bundled data and version drift.
"""
from __future__ import annotations

import json
import plistlib
import sqlite3
import struct
import sys
from collections import defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ERRORS: list[str] = []


def fail(message: str) -> None:
    ERRORS.append(message)


def require(path: str) -> Path:
    p = ROOT / path
    if not p.exists():
        fail(f"Missing required file: {path}")
    return p


def load_json(path: str):
    p = require(path)
    if not p.exists():
        return None
    try:
        with p.open("r", encoding="utf-8") as f:
            return json.load(f)
    except Exception as exc:
        fail(f"Invalid JSON: {path}: {exc}")
        return None


def check_plists() -> None:
    for rel in (
        "SARI/Info.plist",
        "SARIWidget/Info.plist",
        "SARI/PrivacyInfo.xcprivacy",
        "SARIWidget/PrivacyInfo.xcprivacy",
        "SARI/SARI.entitlements",
        "SARIWidget/SARIWidget.entitlements",
    ):
        p = require(rel)
        if not p.exists():
            continue
        try:
            with p.open("rb") as f:
                plistlib.load(f)
        except Exception as exc:
            fail(f"Invalid plist: {rel}: {exc}")


def output_key(path: Path) -> str:
    # .lproj contents intentionally keep their language directory in the app
    # bundle, so equal names across different localizations are not collisions.
    for parent in path.parents:
        if parent.suffix == ".lproj":
            return f"{parent.name}/{path.name}"
    # Xcode's Copy Bundle Resources flattens ordinary group paths. Two ordinary
    # resources with the same basename therefore produce the same bundle output.
    return path.name


def check_app_resource_collisions() -> None:
    roots = [ROOT / "SARI/Resources", ROOT / "SharedResources/data"]
    outputs: dict[str, list[Path]] = defaultdict(list)
    for base in roots:
        if not base.exists():
            continue
        for p in base.rglob("*"):
            if p.is_file():
                outputs[output_key(p)].append(p)

    for key, paths in sorted(outputs.items()):
        if len(paths) > 1:
            pretty = ", ".join(str(p.relative_to(ROOT)) for p in paths)
            fail(f"Duplicate app bundle resource output '{key}': {pretty}")


def caf_duration_seconds(path: Path) -> float | None:
    """Parse enough of a CAF file to validate iOS custom-notification audio.

    SARI's notification files are uncompressed LPCM CAF. iOS custom notification
    sounds must be shorter than 30 seconds, so this release gate verifies the
    actual bundled bytes rather than only checking filenames.
    """
    try:
        data = path.read_bytes()
        if len(data) < 20 or data[:4] != b"caff":
            return None
        pos = 8
        desc = None
        audio_bytes = None
        while pos + 12 <= len(data):
            chunk_type = data[pos:pos + 4]
            chunk_size = struct.unpack(">q", data[pos + 4:pos + 12])[0]
            pos += 12
            if chunk_size < 0:
                chunk_size = len(data) - pos
            if pos + chunk_size > len(data):
                return None
            chunk = data[pos:pos + chunk_size]
            if chunk_type == b"desc" and len(chunk) >= 32:
                sample_rate = struct.unpack(">d", chunk[:8])[0]
                format_id = chunk[8:12]
                _, bytes_per_packet, frames_per_packet, channels, bits = struct.unpack(">IIIII", chunk[12:32])
                desc = (sample_rate, format_id, bytes_per_packet, frames_per_packet, channels, bits)
            elif chunk_type == b"data":
                # CAF data chunk starts with a 4-byte edit count.
                audio_bytes = max(0, chunk_size - 4)
            pos += chunk_size

        if not desc or audio_bytes is None:
            return None
        sample_rate, format_id, bytes_per_packet, frames_per_packet, channels, bits = desc
        if format_id != b"lpcm" or sample_rate <= 0 or bytes_per_packet <= 0 or frames_per_packet <= 0:
            return None
        if channels < 1 or bits not in (8, 16, 24, 32):
            return None
        packets = audio_bytes / bytes_per_packet
        return packets * frames_per_packet / sample_rate
    except Exception:
        return None


def check_adhan_audio() -> None:
    reciters = load_json("SARI/Resources/data/adhan_reciters.json")
    if not isinstance(reciters, dict):
        return
    for item in reciters.get("sounds", []):
        if not isinstance(item, dict):
            continue
        notification = item.get("notification", "")
        preview = item.get("preview", "")
        caf = ROOT / "SARI/Resources" / notification
        m4a = ROOT / "SARI/Resources/audio" / preview
        if caf.is_file():
            duration = caf_duration_seconds(caf)
            if duration is None:
                fail(f"Invalid or unsupported CAF notification sound: {notification}")
            elif duration >= 30:
                fail(f"Adhan notification sound must be under 30 seconds: {notification} = {duration:.2f}s")
        if m4a.is_file():
            head = m4a.read_bytes()[:32]
            if b"ftyp" not in head:
                fail(f"Invalid M4A Adhan preview container: {preview}")


def check_bundled_data() -> None:
    quran = load_json("SARI/Resources/data/quran_tafseer.json")
    if isinstance(quran, list):
        if len(quran) != 6236:
            fail(f"Quran rows must be 6236, got {len(quran)}")
        ids = [x.get("id") for x in quran if isinstance(x, dict)]
        if len(set(ids)) != 6236:
            fail("Quran verse ids are not unique/complete")
        pages = {x.get("page") for x in quran if isinstance(x, dict)}
        if pages != set(range(1, 605)):
            fail("Quran pages must cover exactly 1...604")
        for row in quran:
            if not isinstance(row, dict):
                fail("Quran contains a non-object row")
                break
            ls, le = row.get("line_start"), row.get("line_end")
            if not isinstance(ls, int) or not isinstance(le, int) or not (1 <= ls <= 15 and 1 <= le <= 15):
                fail(f"Invalid Quran line range in verse id {row.get('id')}: {ls}...{le}")
                break

    countries = load_json("SARI/Resources/data/countries.json")
    if isinstance(countries, list):
        codes = [x.get("code") for x in countries if isinstance(x, dict)]
        if len(countries) != 195 or len(set(codes)) != 195:
            fail(f"Countries must contain 195 unique codes, got {len(countries)} rows / {len(set(codes))} unique")
        if "IL" in set(codes):
            fail("countries.json must not contain code IL")
        if "PS" not in set(codes):
            fail("countries.json must contain Palestine (PS)")

        # Keep the Swift travel selector exactly aligned with countries.json.
        import re
        travel_swift = (ROOT / "SARI/Sources/Core/TravelService.swift").read_text(encoding="utf-8")
        match = re.search(r'private static let sovereignCodes: \[String\] = """\s*(.*?)\s*"""\.split', travel_swift, re.S)
        if not match:
            fail("Unable to locate TravelCatalog.sovereignCodes in TravelService.swift")
        else:
            swift_codes = match.group(1).split()
            if len(swift_codes) != 195 or len(set(swift_codes)) != 195:
                fail(f"TravelCatalog must contain 195 unique codes, got {len(swift_codes)} rows / {len(set(swift_codes))} unique")
            if set(swift_codes) != set(codes):
                missing = sorted(set(codes) - set(swift_codes))
                extra = sorted(set(swift_codes) - set(codes))
                fail(f"TravelCatalog/countries.json mismatch. Missing={missing}, extra={extra}")

    adhkar = load_json("SARI/Resources/data/adhkar.json")
    if isinstance(adhkar, dict):
        categories = adhkar.get("categories", [])
        count = sum(len(x.get("items", [])) for x in categories if isinstance(x, dict))
        if count < 50:
            fail(f"Adhkar library unexpectedly small: {count}")

    scholars = load_json("SARI/Resources/data/scholars.json")
    if isinstance(scholars, dict):
        items = scholars.get("items", [])
        if len(items) != 17:
            fail(f"Scholars list must contain 17 contacts, got {len(items)}")
        phones = [x.get("phone") for x in items if isinstance(x, dict)]
        if len(set(phones)) != len(phones):
            fail("Duplicate scholar phone number found")

    sounds = load_json("SARI/Resources/data/adhan_reciters.json")
    if isinstance(sounds, dict):
        entries = sounds.get("sounds", [])
        if len(entries) != 4:
            fail(f"Expected 4 Adhan options, got {len(entries)}")
        for item in entries:
            if not isinstance(item, dict):
                fail("Invalid Adhan sound entry")
                continue
            preview = item.get("preview", "")
            notification = item.get("notification", "")
            if not (ROOT / "SARI/Resources/audio" / preview).is_file():
                fail(f"Missing Adhan preview: {preview}")
            if not (ROOT / "SARI/Resources" / notification).is_file():
                fail(f"Missing Adhan notification sound: {notification}")


def check_sqlite() -> None:
    p = require("SARI/Resources/data/fiqh_pages.sqlite3")
    if not p.exists():
        return
    try:
        con = sqlite3.connect(f"file:{p}?mode=ro", uri=True)
        integrity = con.execute("PRAGMA integrity_check").fetchone()
        if not integrity or integrity[0] != "ok":
            fail(f"fiqh_pages.sqlite3 integrity_check failed: {integrity}")
        table = con.execute("SELECT name FROM sqlite_master WHERE type='table' AND name='pages'").fetchone()
        if not table:
            fail("fiqh_pages.sqlite3 is missing pages table")
        else:
            count = con.execute("SELECT COUNT(*) FROM pages").fetchone()[0]
            if count != 4099:
                fail(f"Expected 4099 fiqh pages, got {count}")
        con.close()
    except Exception as exc:
        fail(f"Unable to validate fiqh_pages.sqlite3: {exc}")


def check_project_config() -> None:
    p = require("project.yml")
    if not p.exists():
        return
    text = p.read_text(encoding="utf-8")
    required = (
        "SWIFT_VERSION: 6.0",
        "IPHONEOS_DEPLOYMENT_TARGET: 17.0",
        "PRODUCT_BUNDLE_IDENTIFIER: sa.sari.app",
        "PRODUCT_BUNDLE_IDENTIFIER: sa.sari.app.widget",
        'GENERATE_INFOPLIST_FILE: "NO"',
        "INFOPLIST_FILE: SARI/Info.plist",
        "INFOPLIST_FILE: SARIWidget/Info.plist",
        "exactVersion: 0.1.0",
    )
    for token in required:
        if token not in text:
            fail(f"project.yml is missing required setting: {token}")
    if text.count("MARKETING_VERSION: 0.9.5") != 2:
        fail("App and widget MARKETING_VERSION must both be 0.9.5")
    if text.count("CURRENT_PROJECT_VERSION: 14") != 2:
        fail("App and widget CURRENT_PROJECT_VERSION must both be 14")


def check_local_ai_config() -> None:
    model = load_json("LocalAIPack/recommended_model.json")
    if not isinstance(model, dict):
        return
    expected_sha = "626b4a6678b86442240e33df819e00132d3ba7dddfe1cdc4fbb18e0a9615c62d"
    expected_url = "https://huggingface.co/Qwen/Qwen2.5-3B-Instruct-GGUF/resolve/main/qwen2.5-3b-instruct-q4_k_m.gguf"
    if model.get("sha256") != expected_sha:
        fail("Offline AI model SHA-256 drifted from the verified Qwen2.5 3B Q4_K_M file")
    if model.get("modelURL") != expected_url:
        fail("Offline AI model URL drifted from the validated Hugging Face asset")

    swift = require("SARI/Sources/Core/LocalFiqhPack.swift")
    if swift.exists():
        text = swift.read_text(encoding="utf-8")
        if expected_sha not in text or expected_url not in text:
            fail("LocalFiqhPack.swift does not match LocalAIPack/recommended_model.json")





def check_swift6_api_compatibility() -> None:
    """Catch known type-check-only traps that `swiftc -parse` cannot detect.

    This release gate was added after Xcode 16.4 correctly rejected
    `URLError.Code.cannotResume`: that member does not exist even though the
    source is syntactically valid. Keep the scan explicit and deterministic.
    """
    local_pack = require("SARI/Sources/Core/LocalFiqhPack.swift")
    downloader = require("SARI/Sources/Core/ResumableFileDownloader.swift")
    for path in (local_pack, downloader):
        if not path.exists():
            continue
        text = path.read_text(encoding="utf-8")
        if ".cannotResume" in text:
            fail(f"Unsupported URLError.Code.cannotResume in {path.relative_to(ROOT)} (Xcode 16.4/Swift 6)")

    if downloader.exists():
        text = downloader.read_text(encoding="utf-8")
        required_tokens = (
            "NSURLSessionDownloadTaskResumeData",
            "startedFromResumeData",
            "Data.WritingOptions.atomic",
        )
        for token in required_tokens:
            if token not in text:
                fail(f"Resumable downloader compatibility guard missing: {token}")

def check_notification_delegate() -> None:
    p = require("SARI/Sources/App/SariAppDelegate.swift")
    if not p.exists():
        return
    text = p.read_text(encoding="utf-8")
    if "final class SariNotificationDelegate: NSObject, UNUserNotificationCenterDelegate" not in text:
        fail("Foreground notification delegate must stay separate for Swift 6/Xcode 16.4")
    if "final class SariAppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate" in text:
        fail("Do not combine UIApplicationDelegate and UNUserNotificationCenterDelegate under Swift 6")
    if "withCompletionHandler completionHandler" not in text:
        fail("Foreground Adhan notification delegate is missing its completion-handler callback")

def check_required_files() -> None:
    for rel in (
        ".github/workflows/ios-build.yml",
        "SARI/Resources/KFGQPCAnRegular.ttf",
        "SARI/Resources/KFGQPCHafsUthmanic.ttf",
        "SharedResources/data/travel_directory_schema.json",
        "SARI/Sources/Core/MushafPageRepository.swift",
        "SARI/Sources/Core/LocalFiqhEngine.swift",
        "LocalAIPack/recommended_model.json",
    ):
        require(rel)


check_required_files()
check_plists()
check_app_resource_collisions()
check_bundled_data()
check_adhan_audio()
check_sqlite()
check_project_config()
check_local_ai_config()
check_swift6_api_compatibility()
check_notification_delegate()

if ERRORS:
    print("SARI iOS preflight FAILED:", file=sys.stderr)
    for i, error in enumerate(ERRORS, 1):
        print(f"  {i}. {error}", file=sys.stderr)
    sys.exit(1)

print("SARI iOS preflight OK")
print("- no duplicate app resource outputs")
print("- plists/resources/data/sqlite validated")
print("- Adhan CAF/M4A assets validated; custom notification sounds are < 30s")
print("- Swift 6/Xcode 16.4 compatibility traps validated")
print("- app/widget version and core XcodeGen settings aligned")
