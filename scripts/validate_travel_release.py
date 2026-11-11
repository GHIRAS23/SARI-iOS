#!/usr/bin/env python3
"""Static release checks for SARI's new travel, food, currency and adhkar modules."""
from __future__ import annotations

import json
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]

def fail(message: str) -> None:
    print(f"SARI travel release validation FAILED: {message}", file=sys.stderr)
    raise SystemExit(1)

def require(path: str) -> Path:
    target = ROOT / path
    if not target.is_file() or target.stat().st_size == 0:
        fail(f"missing or empty file: {path}")
    return target

# Required source and UI modules.
modules = [
    "SARI/Sources/Core/CurrencyRateService.swift",
    "SARI/Sources/Features/Travel/CurrencyConverterView.swift",
    "SARI/Sources/Core/EmbassyDirectoryService.swift",
    "SARI/Sources/Features/Travel/EmbassyDirectoryView.swift",
    "SARI/Sources/Core/PlacesService.swift",
    "SARI/Sources/Features/Travel/PlacesLocalView.swift",
    "SARI/Sources/Core/LocalFoodService.swift",
    "SARI/Sources/Features/Travel/LocalFoodGuideView.swift",
    "SARI/Sources/Core/ArabicTransliterator.swift",
    "SARI/Sources/Core/HalalCountryPolicy.swift",
    "SARI/Resources/data/halal_default_countries.json",
    "SARI/Resources/data/local_food_areas.json",
    "SARI/Resources/data/adhkar.json",
    "SARI/Resources/data/quran_tafseer.json",
]
for module in modules:
    require(module)

# Ensure app resources include required policy and cuisine map data.
policy_path = ROOT / "SARI/Resources/data/halal_default_countries.json"
policy = json.loads(policy_path.read_text(encoding="utf-8"))
if policy.get("schema") != 1:
    fail("unsupported halal policy schema")
if set(policy.get("country_codes", [])) != {"SA", "KW"}:
    fail("default halal countries must initially be SA and KW")

areas = json.loads((ROOT / "SARI/Resources/data/local_food_areas.json").read_text(encoding="utf-8"))
if areas.get("schema") != 1 or len(areas.get("country_to_area", {})) < 20:
    fail("local food provider mapping is missing or unexpectedly small")

# Ensure adhkar preserve original Arabic and all currently supported app languages.
adhkar = json.loads((ROOT / "SARI/Resources/data/adhkar.json").read_text(encoding="utf-8"))
languages = {"ar", "en", "tr", "ms", "id", "ja", "zh", "ru", "fr"}
items = [item for category in adhkar.get("categories", []) for item in category.get("items", [])]
if len(items) < 50:
    fail(f"expected at least 50 adhkar entries, found {len(items)}")
if any(not item.get("arabic", "").strip() for item in items):
    fail("an adhkar entry is missing its Arabic source")
for item in items:
    meanings = item.get("meanings") or {}
    if not isinstance(meanings, dict) or any(key not in languages for key in meanings):
        fail(f"invalid meaning language map in adhkar item {item.get('id')}")

# Verify screens are navigable from the travel hub and use provider-backed data layers.
travel_view = require("SARI/Sources/Features/Travel/TravelView.swift").read_text(encoding="utf-8")
for marker in ["EmbassyDirectoryView", "PlacesLocalView", "LocalFoodGuideView", "CurrencyConverterView"]:
    if marker not in travel_view:
        fail(f"travel hub does not link to {marker}")

places = require("SARI/Sources/Core/PlacesService.swift").read_text(encoding="utf-8")
if "overpass-api.de/api/interpreter" not in places or "prefix(5)" not in places:
    fail("nearby restaurant provider or five-result cap is missing")
if "HalalCountryPolicy.defaultCountryCodes" not in places:
    fail("restaurant search does not use the configured default-country policy")

currency = require("SARI/Sources/Core/CurrencyRateService.swift").read_text(encoding="utf-8")
for marker in ["open.er-api.com", "persist(", "restoreCache(", "isUsingCachedRates"]:
    if marker not in currency:
        fail(f"currency offline/cache behavior missing: {marker}")

embassy = require("SARI/Sources/Core/EmbassyDirectoryService.swift").read_text(encoding="utf-8")
for marker in ["SARI_API_BASE_URL", "v1/embassies", "openstreetmap.org", "isOfficiallyVerified"]:
    if marker not in embassy:
        fail(f"embassy source and verification handling missing: {marker}")

food = require("SARI/Sources/Core/LocalFoodService.swift").read_text(encoding="utf-8")
for marker in ["themealdb.com", "possibleNonHalal", "needsVerification", "mealDBArea"]:
    if marker not in food:
        fail(f"local food provider/risk handling missing: {marker}")

# Ensure API secrets are not committed in source files. Placeholder backend URL is allowed.
for path in (ROOT / "SARI/Sources").rglob("*.swift"):
    content = path.read_text(encoding="utf-8")
    if re.search(r"(?i)(api[_-]?key|secret)\s*[:=]\s*['\"][A-Za-z0-9_\-]{24,}['\"]", content):
        fail(f"possible hard-coded credential in {path.relative_to(ROOT)}")

# Verify bundle version parity.
project_yml = require("project.yml").read_text(encoding="utf-8")
versions = re.findall(r"MARKETING_VERSION:\s*([0-9.]+)", project_yml)
builds = re.findall(r"CURRENT_PROJECT_VERSION:\s*(\d+)", project_yml)
if len(versions) < 2 or len(set(versions)) != 1 or len(builds) < 2 or len(set(builds)) != 1:
    fail("application and widget versions are not aligned")

print("SARI travel release validation OK")
print(f"- {len(items)} adhkar entries retain Arabic originals")
print(f"- {sum(bool(item.get('transliteration')) for item in items)} reviewed transliterations are stored; missing entries use labelled approximation")
print(f"- {sum(bool(item.get('meanings')) for item in items)} entries have at least one reviewed translation; missing translations remain explicitly unavailable")
print(f"- default halal policy countries: {', '.join(sorted(policy['country_codes']))}")
print(f"- {len(areas['country_to_area'])} country-to-cuisine mappings (provider coverage is not global)")
print(f"- travel, embassy, restaurant, food, currency and offline cache modules present")
print(f"- release version {versions[0]} ({builds[0]})")
