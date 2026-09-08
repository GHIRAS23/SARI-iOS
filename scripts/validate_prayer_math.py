#!/usr/bin/env python3
"""Numerical regression for the solar-time formula mirrored in PrayerService.swift.

The Makkah snapshot exists specifically to prevent a regression to the previous
multi-hour shift (for example Dhuhr at night). It intentionally uses broad,
realistic windows rather than claiming minute-perfect official authority.
"""
from __future__ import annotations

from datetime import datetime
from math import acos, atan, cos, pi, sin, tan
from zoneinfo import ZoneInfo


def calculate(date: datetime, latitude: float, longitude: float):
    day = date.timetuple().tm_yday
    days = 366 if date.year % 4 == 0 and (date.year % 100 != 0 or date.year % 400 == 0) else 365
    gamma = 2.0 * pi / days * (day - 1)
    equation = 229.18 * (
        0.000075
        + 0.001868 * cos(gamma)
        - 0.032077 * sin(gamma)
        - 0.014615 * cos(2 * gamma)
        - 0.040849 * sin(2 * gamma)
    )
    declination = (
        0.006918
        - 0.399912 * cos(gamma)
        + 0.070257 * sin(gamma)
        - 0.006758 * cos(2 * gamma)
        + 0.000907 * sin(2 * gamma)
        - 0.002697 * cos(3 * gamma)
        + 0.00148 * sin(3 * gamma)
    )
    zone_minutes = date.utcoffset().total_seconds() / 60
    noon = 720.0 - 4.0 * longitude - equation + zone_minutes

    def hour_angle(altitude: float) -> float:
        lat = latitude * pi / 180
        alt = altitude * pi / 180
        numerator = sin(alt) - sin(lat) * sin(declination)
        denominator = cos(lat) * cos(declination)
        value = max(-1.0, min(1.0, numerator / denominator))
        return acos(value) * 180 / pi

    sunrise_angle = hour_angle(-0.833)
    fajr_angle = hour_angle(-18.5)
    declination_degrees = declination * 180 / pi
    asr_altitude = atan(1.0 / (1.0 + tan(abs((latitude - declination_degrees) * pi / 180)))) * 180 / pi
    asr_angle = hour_angle(asr_altitude)

    values = {
        "fajr": noon - 4 * fajr_angle,
        "sunrise": noon - 4 * sunrise_angle,
        "dhuhr": noon,
        "asr": noon + 4 * asr_angle,
        "maghrib": noon + 4 * sunrise_angle,
    }
    values["isha"] = values["maghrib"] + 90
    return values


def hhmm(minutes: float) -> str:
    minutes = int(round(minutes)) % (24 * 60)
    return f"{minutes // 60:02d}:{minutes % 60:02d}"


def main() -> None:
    makkah = datetime(2026, 9, 8, 12, tzinfo=ZoneInfo("Asia/Riyadh"))
    times = calculate(makkah, 21.3891, 39.8579)

    ordered = [times[k] for k in ("fajr", "sunrise", "dhuhr", "asr", "maghrib", "isha")]
    if ordered != sorted(ordered):
        raise SystemExit(f"Prayer order regression: {times}")

    # Sanity windows in local civil minutes for Makkah in early September.
    windows = {
        "fajr": (4 * 60, 6 * 60),
        "sunrise": (5 * 60, 7 * 60),
        "dhuhr": (11 * 60 + 30, 13 * 60),
        "asr": (14 * 60, 17 * 60),
        "maghrib": (17 * 60 + 30, 20 * 60),
        "isha": (19 * 60, 22 * 60),
    }
    for key, (low, high) in windows.items():
        if not low <= times[key] <= high:
            raise SystemExit(f"{key} outside Makkah sanity window: {hhmm(times[key])}")

    print("Prayer math regression OK")
    print("Makkah 2026-09-08:", ", ".join(f"{k}={hhmm(v)}" for k, v in times.items()))


if __name__ == "__main__":
    main()
