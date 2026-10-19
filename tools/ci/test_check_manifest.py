"""pytest: check_manifest.py fails on banned permissions and on phones, in every manifest format.

The plain-XML fixtures are in tools/ci/fixtures/manifest/. The binary formats (AXML inside an APK,
aapt2 protobuf XML inside an AAB) are built here by small encoders that follow the published formats
(Android's ResourceTypes.h and aapt2's Resources.proto), so no real build is needed. CI also runs
the script on the APK it really exports (.github/workflows/ci.yml, android-debug job), where aapt2's
own permission dump checks the AXML reader.
"""
from __future__ import annotations

import struct
import zipfile
from pathlib import Path

import pytest

import check_manifest as cm

FIXTURES = Path(__file__).resolve().parent / "fixtures" / "manifest"

# (tag, attributes, children); attribute values are str, bool or int.
Tree = tuple[str, dict[str, object], list["Tree"]]

CLEAN: Tree = ("manifest", {"package": "com.spiroganas.gemmine"}, [
    ("supports-screens", {"smallScreens": False, "normalScreens": False, "largeScreens": True, "xlargeScreens": True}, []),
    ("application", {"label": "Gem Mines of Number Mountain"}, []),
])
WITH_INTERNET: Tree = ("manifest", {"package": "com.spiroganas.gemmine"}, [
    ("supports-screens", {"smallScreens": False, "normalScreens": False}, []),
    ("uses-permission", {"name": "android.permission.INTERNET"}, []),
    ("application", {}, []),
])
PHONES: Tree = ("manifest", {}, [("supports-screens", {"smallScreens": True, "normalScreens": True}, [])])
SMALLEST_WIDTH: Tree = ("manifest", {}, [("supports-screens", {"smallScreens": False, "normalScreens": False, "requiresSmallestWidthDp": 600}, [])])


# --- Encoders for the binary formats (test fixtures only) ---------------------------------------


def _names(tree: Tree, attrs: list[str], tags: list[str]) -> None:
    tag, attributes, children = tree
    tags.append(tag)
    for key, value in attributes.items():
        attrs.append(key)
        if isinstance(value, str):
            tags.append(value)
    for child in children:
        _names(child, attrs, tags)


def _pool(strings: list[str], utf8: bool) -> bytes:
    body = b""
    offsets: list[int] = []
    for text in strings:
        offsets.append(len(body))
        if utf8:
            encoded = text.encode("utf-8")
            body += bytes([len(text), len(encoded)]) + encoded + b"\x00"
        else:
            body += struct.pack("<H", len(text)) + text.encode("utf-16-le") + b"\x00\x00"
    body += b"\x00" * (-len(body) % 4)
    header_size = 28
    strings_start = header_size + 4 * len(strings)
    size = strings_start + len(body)
    flags = 0x100 if utf8 else 0
    return struct.pack("<HHIIIIII", 0x0001, header_size, size, len(strings), 0, flags, strings_start, 0) + struct.pack(f"<{len(strings)}I", *offsets) + body


def encode_axml(tree: Tree, utf8: bool = False, strip_names: bool = False) -> bytes:
    """Android binary XML. Attribute names come first in the pool, matched by the resource map."""
    attrs: list[str] = []
    others: list[str] = []
    _names(tree, attrs, others)
    attr_names = list(dict.fromkeys(attrs))
    ids = {name: rid for rid, name in cm.ATTR_IDS.items()}
    strings = [("" if strip_names and name in ids else name) for name in attr_names]
    strings += [s for s in dict.fromkeys(others) if s not in strings]

    def index(text: str) -> int:
        return strings.index(text)

    def attr_index(name: str) -> int:
        return attr_names.index(name)

    chunks = b""

    def element(node: Tree) -> bytes:
        tag, attributes, children = node
        out = b""
        packed = b""
        for key, value in attributes.items():
            if isinstance(value, bool):
                raw, vtype, data = 0xFFFFFFFF, 0x12, 0xFFFFFFFF if value else 0
            elif isinstance(value, int):
                raw, vtype, data = 0xFFFFFFFF, 0x10, value
            else:
                raw, vtype, data = index(value), 0x03, index(value)
            packed += struct.pack("<IIIHBBI", 0xFFFFFFFF, attr_index(key), raw, 8, 0, vtype, data)
        body = struct.pack("<IIHHHHHH", 0xFFFFFFFF, index(tag), 20, 20, len(attributes), 0, 0, 0) + packed
        out += struct.pack("<HHIII", 0x0102, 16, 16 + len(body), 1, 0xFFFFFFFF) + body
        for child in children:
            out += element(child)
        out += struct.pack("<HHIIIII", 0x0103, 16, 24, 1, 0xFFFFFFFF, 0xFFFFFFFF, index(tag))
        return out

    resource_ids = [ids.get(name, 0) for name in attr_names]
    chunks += _pool(strings, utf8)
    chunks += struct.pack("<HHI", 0x0180, 8, 8 + 4 * len(resource_ids)) + struct.pack(f"<{len(resource_ids)}I", *resource_ids)
    chunks += element(tree)
    return struct.pack("<HHI", 0x0003, 8, 8 + len(chunks)) + chunks


def _varint(value: int) -> bytes:
    out = b""
    while True:
        byte = value & 0x7F
        value >>= 7
        if value:
            out += bytes([byte | 0x80])
        else:
            return out + bytes([byte])


def _field(number: int, payload: bytes | int) -> bytes:
    if isinstance(payload, int):
        return _varint(number << 3) + _varint(payload)
    return _varint((number << 3) | 2) + _varint(len(payload)) + payload


def encode_proto(tree: Tree, keep_raw_values: bool = True) -> bytes:
    """aapt2 protobuf XML (XmlNode) as stored in an AAB's base/manifest/AndroidManifest.xml."""

    def element(node: Tree) -> bytes:
        tag, attributes, children = node
        out = _field(3, tag.encode())
        for key, value in attributes.items():
            attr = _field(1, cm.ANDROID_NS.encode()) + _field(2, key.encode())
            text = str(value).lower() if isinstance(value, bool) else str(value)
            if keep_raw_values:
                attr += _field(3, text.encode())
            if isinstance(value, bool):
                attr += _field(6, _field(7, _field(8, int(value))))
            elif isinstance(value, int):
                attr += _field(6, _field(7, _field(6, value)))
            else:
                attr += _field(6, _field(2, _field(1, text.encode())))
            out += _field(4, attr)
        for child in children:
            out += _field(5, _field(1, element(child)))
        return out

    return _field(1, element(tree))


def _zip(path: Path, member: str, data: bytes) -> Path:
    with zipfile.ZipFile(path, "w") as archive:
        archive.writestr(member, data)
        archive.writestr("classes.dex", b"dex\n")
    return path


@pytest.fixture(autouse=True)
def _no_android_tools(monkeypatch: pytest.MonkeyPatch) -> None:
    """The readers under test, not whatever bundletool or aapt2 happens to be installed."""
    monkeypatch.setattr(cm, "_tool", lambda env_name, command: None)


# --- Plain XML ---------------------------------------------------------------------------------


def test_the_clean_fixture_passes() -> None:
    assert cm.main([str(FIXTURES / "clean.xml")]) == 0


def test_internet_and_the_advertising_id_fail() -> None:
    problems = cm.check(cm.load_manifest(FIXTURES / "internet.xml"))
    assert any("android.permission.INTERNET" in p for p in problems)
    assert any("AD_ID" in p for p in problems)
    assert cm.main([str(FIXTURES / "internet.xml")]) == 1


def test_a_manifest_that_lets_phones_install_fails() -> None:
    problems = cm.check(cm.load_manifest(FIXTURES / "phones.xml"))
    assert any("smallScreens" in p for p in problems)
    assert any("normalScreens" in p for p in problems)


@pytest.mark.parametrize("permission", cm.BANNED_PERMISSIONS)
def test_every_banned_permission_fails(permission: str) -> None:
    manifest = cm.parse_text_xml(
        f'<manifest xmlns:android="{cm.ANDROID_NS}"><supports-screens android:smallScreens="false" android:normalScreens="false"/>'
        f'<uses-permission android:name="{permission}"/></manifest>'
    )
    assert cm.check(manifest) == [f"banned permission requested: {permission}"]


def test_the_sdk_23_permission_tag_counts_too() -> None:
    manifest = cm.parse_text_xml(f'<manifest xmlns:android="{cm.ANDROID_NS}"><supports-screens android:smallScreens="false" android:normalScreens="false"/><uses-permission-sdk-23 android:name="android.permission.CAMERA"/></manifest>')
    assert cm.check(manifest) == ["banned permission requested: android.permission.CAMERA"]


def test_a_harmless_permission_is_allowed() -> None:
    manifest = cm.parse_text_xml(f'<manifest xmlns:android="{cm.ANDROID_NS}"><supports-screens android:smallScreens="false" android:normalScreens="false"/><uses-permission android:name="android.permission.VIBRATE"/></manifest>')
    assert cm.check(manifest) == []


def test_missing_supports_screens_fails() -> None:
    manifest = cm.parse_text_xml(f'<manifest xmlns:android="{cm.ANDROID_NS}"/>')
    assert any("supports-screens" in p for p in cm.check(manifest))


def test_the_smallest_width_is_optional_but_checked_when_present_or_required() -> None:
    base = f'<manifest xmlns:android="{cm.ANDROID_NS}"><supports-screens android:smallScreens="false" android:normalScreens="false"{{}}/></manifest>'
    without = cm.parse_text_xml(base.format(""))
    assert cm.check(without) == []
    assert cm.check(without, require_smallest_width=600) == ["android:requiresSmallestWidthDp is missing (required: 600)"]
    assert cm.check(cm.parse_text_xml(base.format(' android:requiresSmallestWidthDp="600"')), require_smallest_width=600) == []
    assert any("below" in p for p in cm.check(cm.parse_text_xml(base.format(' android:requiresSmallestWidthDp="320"'))))


def test_unreadable_files_exit_2(tmp_path: Path) -> None:
    assert cm.main([str(tmp_path / "missing.aab")]) == 2
    broken = tmp_path / "broken.xml"
    broken.write_text("<manifest", encoding="utf-8")
    assert cm.main([str(broken)]) == 2
    not_zip = tmp_path / "build.apk"
    not_zip.write_bytes(b"not a zip")
    assert cm.main([str(not_zip)]) == 2


# --- Binary XML (APK) ----------------------------------------------------------------------------


@pytest.mark.parametrize("utf8", [False, True])
def test_the_axml_reader_reads_tags_strings_and_booleans(utf8: bool) -> None:
    root = cm.parse_axml(encode_axml(CLEAN, utf8=utf8))
    assert root.tag == "manifest"
    assert root.attrs["package"] == "com.spiroganas.gemmine"
    screens = root.children[0]
    assert screens.tag == "supports-screens"
    assert screens.attrs == {"smallScreens": "false", "normalScreens": "false", "largeScreens": "true", "xlargeScreens": "true"}
    assert root.children[1].attrs["label"] == "Gem Mines of Number Mountain"


def test_axml_attribute_names_stripped_to_resource_ids_are_still_found() -> None:
    root = cm.parse_axml(encode_axml(WITH_INTERNET, strip_names=True))
    assert cm.permissions(root) == ["android.permission.INTERNET"]
    assert root.children[0].attrs["smallScreens"] == "false"


def test_an_apk_is_checked_from_its_binary_manifest(tmp_path: Path) -> None:
    clean = _zip(tmp_path / "clean.apk", "AndroidManifest.xml", encode_axml(CLEAN))
    assert cm.main([str(clean)]) == 0
    bad = _zip(tmp_path / "bad.apk", "AndroidManifest.xml", encode_axml(WITH_INTERNET))
    assert cm.main([str(bad)]) == 1
    phones = _zip(tmp_path / "phones.apk", "AndroidManifest.xml", encode_axml(PHONES))
    assert cm.main([str(phones)]) == 1


def test_axml_integers_are_read() -> None:
    root = cm.parse_axml(encode_axml(SMALLEST_WIDTH))
    assert root.children[0].attrs["requiresSmallestWidthDp"] == "600"
    assert cm.check(root, require_smallest_width=600) == []


def test_aapt2_permissions_also_fail_an_apk(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    clean = _zip(tmp_path / "clean.apk", "AndroidManifest.xml", encode_axml(CLEAN))
    monkeypatch.setattr(cm, "aapt2_permissions", lambda path: ["android.permission.RECORD_AUDIO"])
    assert cm.main([str(clean)]) == 1


# --- Protobuf XML (AAB) --------------------------------------------------------------------------


@pytest.mark.parametrize("keep_raw_values", [True, False])
def test_the_protobuf_reader_reads_raw_and_compiled_values(keep_raw_values: bool) -> None:
    root = cm.parse_proto_xml(encode_proto(SMALLEST_WIDTH, keep_raw_values))
    assert root.tag == "manifest"
    assert root.children[0].attrs == {"smallScreens": "false", "normalScreens": "false", "requiresSmallestWidthDp": "600"}


def test_an_aab_is_checked_from_its_protobuf_manifest(tmp_path: Path) -> None:
    clean = _zip(tmp_path / "clean.aab", cm.AAB_MANIFEST, encode_proto(CLEAN))
    assert cm.main([str(clean)]) == 0
    bad = _zip(tmp_path / "bad.aab", cm.AAB_MANIFEST, encode_proto(WITH_INTERNET, keep_raw_values=False))
    assert cm.main([str(bad)]) == 1
    phones = _zip(tmp_path / "phones.aab", cm.AAB_MANIFEST, encode_proto(PHONES))
    assert cm.main([str(phones)]) == 1


def test_an_aab_without_a_manifest_is_unreadable(tmp_path: Path) -> None:
    empty = _zip(tmp_path / "empty.aab", "base/dex/classes.dex", b"")
    assert cm.main([str(empty)]) == 2


def test_bundletool_output_is_used_when_available(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    aab = _zip(tmp_path / "clean.aab", cm.AAB_MANIFEST, encode_proto(CLEAN))
    monkeypatch.setattr(cm, "_bundletool_manifest", lambda path: (FIXTURES / "internet.xml").read_text(encoding="utf-8"))
    assert cm.main([str(aab)]) == 1  # bundletool's dump wins over the built-in reader
