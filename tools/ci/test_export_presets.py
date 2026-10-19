"""pytest: the shipped game stays offline and private (CLAUDE.md rules 1 and 2).

Parses export_presets.cfg and fails if any preset requests the INTERNET permission, any
other Android permission, or would ship tests, tools, docs or Charlie's private data.
"""
from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PRESETS = ROOT / "export_presets.cfg"

# Folders that must never be packed into the app. The test framework is dev-only too: it holds
# TCP/HTTP editor-integration code that a children's-app review would otherwise have to explain.
MUST_EXCLUDE = ("android/*", "tools/*", "tests/*", "docs/*", "private/*", "addons/gdUnit4/*")


def parse_presets() -> dict[str, dict[str, object]]:
    """{preset name: {"platform": ..., "exclude_filter": ..., "options": {key: raw value}}}."""
    presets: dict[int, dict[str, object]] = {}
    section = ""
    for raw in PRESETS.read_text(encoding="utf-8").splitlines():
        line = raw.strip()
        if not line or line.startswith(";"):
            continue
        match = re.fullmatch(r"\[preset\.(\d+)(\.options)?\]", line)
        if match:
            index = int(match.group(1))
            presets.setdefault(index, {"options": {}})
            section = "options" if match.group(2) else "preset"
            current = presets[index]
            continue
        if "=" not in line or not section:
            continue
        key, value = line.split("=", 1)
        if section == "options":
            current["options"][key] = value  # type: ignore[index]
        else:
            current[key] = value.strip('"')
    return {str(p["name"]): p for p in presets.values()}


def android_presets() -> dict[str, dict[str, object]]:
    return {name: p for name, p in parse_presets().items() if p.get("platform") == "Android"}


def test_both_android_presets_exist() -> None:
    assert set(android_presets()) == {"Android", "Android AAB"}


def test_no_preset_requests_the_internet_permission() -> None:
    for name, preset in android_presets().items():
        options = preset["options"]
        assert options.get("permissions/internet") == "false", f"{name}: INTERNET must be off"  # type: ignore[union-attr]
        custom = options.get("permissions/custom_permissions", "")  # type: ignore[union-attr]
        assert "INTERNET" not in custom.upper(), f"{name}: INTERNET listed as a custom permission"


def test_no_preset_requests_any_other_permission() -> None:
    # Every permission toggle must be false, and no custom permission may be listed. The game
    # needs none: no location, contacts, camera, microphone or storage access (rule 2).
    for name, preset in android_presets().items():
        options: dict[str, str] = preset["options"]  # type: ignore[assignment]
        enabled = [key for key, value in options.items() if key.startswith("permissions/") and key != "permissions/custom_permissions" and value.strip() != "false"]
        assert enabled == [], f"{name}: permissions turned on: {enabled}"
        assert options.get("permissions/custom_permissions", "PackedStringArray()").replace(" ", "") == "PackedStringArray()", f"{name}: custom permissions are not allowed"


def test_presets_keep_dev_folders_and_private_data_out_of_the_app() -> None:
    for name, preset in android_presets().items():
        excluded = str(preset.get("exclude_filter", ""))
        for pattern in MUST_EXCLUDE:
            assert pattern in excluded, f"{name}: exclude_filter must contain {pattern}"


def test_presets_agree_on_the_package_id_and_abis() -> None:
    packages = {p["options"].get("package/unique_name") for p in android_presets().values()}  # type: ignore[union-attr]
    assert packages == {'"com.spiroganas.gemmine"'}
    for name, preset in android_presets().items():
        options: dict[str, str] = preset["options"]  # type: ignore[assignment]
        assert options.get("architectures/arm64-v8a") == "true", name
        assert options.get("architectures/x86_64") == "true", name


# --- Phase 3, Sprint 25 (every screen size, phones included) and Sprint 38 (the pinned target SDK) ------------------

TARGET_SDK_FILE = ROOT / ".android-target-sdk"
CI_WORKFLOW = ROOT / ".github" / "workflows" / "ci.yml"


def pinned_target_sdk() -> str:
    return TARGET_SDK_FILE.read_text(encoding="utf-8").strip()


def test_presets_support_every_screen_size_phones_included() -> None:
    # Godot writes these into <supports-screens>; small and normal screens are phones, which are
    # supported (Spiro, docs/decisions.md, 2026-10-19 "Phones are supported").
    # tools/ci/check_manifest.py checks the built manifest too.
    for name, preset in android_presets().items():
        options: dict[str, str] = preset["options"]  # type: ignore[assignment]
        assert options.get("screen/support_small") == "true", f"{name}: small screens (phones) must stay on"
        assert options.get("screen/support_normal") == "true", f"{name}: normal screens (phones) must stay on"
        assert options.get("screen/support_large") == "true", f"{name}: large screens (7-inch tablets) must stay on"
        assert options.get("screen/support_xlarge") == "true", f"{name}: xlarge screens (tablets, Chromebooks) must stay on"


def test_presets_build_only_the_two_abis() -> None:
    for name, preset in android_presets().items():
        options: dict[str, str] = preset["options"]  # type: ignore[assignment]
        assert options.get("architectures/armeabi-v7a") == "false", name
        assert options.get("architectures/x86") == "false", name


def test_presets_target_the_pinned_sdk() -> None:
    # Changing the target SDK is the yearly platform update (docs/platform-update.md): bump
    # .android-target-sdk, both presets and the CI SDK packages together.
    pinned = pinned_target_sdk()
    assert pinned.isdigit(), ".android-target-sdk must hold one API level, e.g. 36"
    for name, preset in android_presets().items():
        options: dict[str, str] = preset["options"]  # type: ignore[assignment]
        assert options.get("gradle_build/target_sdk") == f'"{pinned}"', f"{name}: target SDK must be {pinned}"


def test_ci_installs_the_pinned_sdk_platform() -> None:
    pinned = pinned_target_sdk()
    workflow = CI_WORKFLOW.read_text(encoding="utf-8")
    assert f'"platforms;android-{pinned}"' in workflow
    assert f"build-tools;{pinned}." in workflow
