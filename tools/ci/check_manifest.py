"""Checks an exported Android build's manifest for Gem Mines of Number Mountain (P3-S24-06, P3-S25-05).

Run:  python tools/ci/check_manifest.py build/gem-mines.aab
      python tools/ci/check_manifest.py build/gem-mines-debug.apk
      python tools/ci/check_manifest.py path/to/AndroidManifest.xml   (plain or binary XML)

Fails (exit code 1) when the manifest:

  1. Asks for a banned permission (CLAUDE.md rules 1 and 2): INTERNET, ACCESS_FINE_LOCATION,
     ACCESS_COARSE_LOCATION, ACCESS_BACKGROUND_LOCATION, CAMERA, RECORD_AUDIO, READ_CONTACTS or the
     advertising ID (com.google.android.gms.permission.AD_ID).
  2. Does not exclude phones: <supports-screens> must say android:smallScreens="false" and
     android:normalScreens="false" (export preset options screen/support_small and
     screen/support_normal; docs/decisions.md, 2026-10-19). If android:requiresSmallestWidthDp is
     present it must be at least 600; --require-smallest-width 600 makes it mandatory as well.
     Godot 4.7 writes <supports-screens> itself and has no preset option for that attribute, and
     Google Play does not filter on it, so it is optional by default.

Exit code 2 means the file could not be read.

How each format is read (no third-party Python package; the Android tools are used when present):

  - .aab: base/manifest/AndroidManifest.xml is aapt2's protobuf XML. `bundletool dump manifest` is
    used when the BUNDLETOOL environment variable names the bundletool JAR (or `bundletool` is on
    PATH); otherwise a small protobuf reader here decodes it.
  - .apk: AndroidManifest.xml is Android binary XML (AXML), decoded here. When aapt2 is available
    (the AAPT2 environment variable or PATH), `aapt2 dump permissions` is run too and any banned
    permission it reports also fails the check, so the two readers check each other.
  - .xml: plain text (as `bundletool dump manifest` prints it, or a hand-written fixture) or AXML.
"""
from __future__ import annotations

import argparse
import os
import shutil
import struct
import subprocess
import sys
import xml.etree.ElementTree as ET
import zipfile
from dataclasses import dataclass, field
from pathlib import Path

ANDROID_NS = "http://schemas.android.com/apk/res/android"

BANNED_PERMISSIONS = (
    "android.permission.INTERNET",
    "android.permission.ACCESS_FINE_LOCATION",
    "android.permission.ACCESS_COARSE_LOCATION",
    "android.permission.ACCESS_BACKGROUND_LOCATION",
    "android.permission.CAMERA",
    "android.permission.RECORD_AUDIO",
    "android.permission.READ_CONTACTS",
    "com.google.android.gms.permission.AD_ID",
)
PERMISSION_TAGS = ("uses-permission", "uses-permission-sdk-23", "uses-permission-sdk-m")
SMALLEST_WIDTH_DP = 600

AAB_MANIFEST = "base/manifest/AndroidManifest.xml"
APK_MANIFEST = "AndroidManifest.xml"

# android.R.attr ids, for binary manifests whose attribute names were stripped (aapt2 can do that).
ATTR_IDS = {
    0x01010003: "name",
    0x01010284: "smallScreens",
    0x01010285: "normalScreens",
    0x01010286: "largeScreens",
    0x010102BF: "xlargeScreens",
    0x01010364: "requiresSmallestWidthDp",
}


@dataclass
class Element:
    """One manifest element: its tag, its attributes (local names, values as text), its children."""

    tag: str
    attrs: dict[str, str] = field(default_factory=dict)
    children: list["Element"] = field(default_factory=list)

    def iter(self):  # noqa: ANN201 - a generator of Elements
        yield self
        for child in self.children:
            yield from child.iter()


class ManifestError(Exception):
    """The file is not a manifest this script can read."""


# --- Plain XML -----------------------------------------------------------------------------------


def _local(name: str) -> str:
    return name.split("}", 1)[1] if name.startswith("{") else name.split(":", 1)[-1]


def parse_text_xml(text: str) -> Element:
    try:
        root = ET.fromstring(text)
    except ET.ParseError as error:
        raise ManifestError(f"not XML: {error}") from error

    def convert(node: ET.Element) -> Element:
        return Element(_local(node.tag), {_local(k): v for k, v in node.attrib.items()}, [convert(c) for c in node])

    return convert(root)


# --- Android binary XML (AXML), as inside an APK ---------------------------------------------------

_RES_XML_TYPE = 0x0003
_RES_STRING_POOL_TYPE = 0x0001
_RES_XML_RESOURCE_MAP_TYPE = 0x0180
_RES_XML_START_ELEMENT_TYPE = 0x0102
_RES_XML_END_ELEMENT_TYPE = 0x0103
_UTF8_FLAG = 0x100
_NO_INDEX = 0xFFFFFFFF
_TYPE_STRING = 0x03
_TYPE_INT_DEC = 0x10
_TYPE_INT_HEX = 0x11
_TYPE_INT_BOOLEAN = 0x12


def is_axml(data: bytes) -> bool:
    return len(data) >= 8 and struct.unpack_from("<HH", data, 0)[0] == _RES_XML_TYPE


def _string_pool(data: bytes, start: int) -> list[str]:
    _type, header_size, _size, count, _styles, flags, strings_start, _styles_start = struct.unpack_from("<HHIIIIII", data, start)
    offsets = struct.unpack_from(f"<{count}I", data, start + header_size)
    base = start + strings_start
    utf8 = bool(flags & _UTF8_FLAG)
    strings: list[str] = []
    for offset in offsets:
        at = base + offset
        if utf8:
            at += 2 if data[at] & 0x80 else 1  # UTF-16 length, unused
            length = data[at]
            if length & 0x80:
                length = ((length & 0x7F) << 8) | data[at + 1]
                at += 2
            else:
                at += 1
            strings.append(data[at:at + length].decode("utf-8", errors="replace"))
        else:
            length = struct.unpack_from("<H", data, at)[0]
            if length & 0x8000:
                length = ((length & 0x7FFF) << 16) | struct.unpack_from("<H", data, at + 2)[0]
                at += 4
            else:
                at += 2
            strings.append(data[at:at + length * 2].decode("utf-16-le", errors="replace"))
    return strings


def parse_axml(data: bytes) -> Element:
    if not is_axml(data):
        raise ManifestError("not Android binary XML")
    try:
        header_size = struct.unpack_from("<H", data, 2)[0]
        strings: list[str] = []
        resource_ids: list[int] = []
        root: Element | None = None
        stack: list[Element] = []
        at = header_size
        while at + 8 <= len(data):
            chunk_type, chunk_header, chunk_size = struct.unpack_from("<HHI", data, at)
            if chunk_size < 8:
                raise ManifestError("broken chunk")
            if chunk_type == _RES_STRING_POOL_TYPE:
                strings = _string_pool(data, at)
            elif chunk_type == _RES_XML_RESOURCE_MAP_TYPE:
                count = (chunk_size - chunk_header) // 4
                resource_ids = list(struct.unpack_from(f"<{count}I", data, at + chunk_header))
            elif chunk_type == _RES_XML_START_ELEMENT_TYPE:
                body = at + chunk_header
                _ns, name, attr_start, attr_size, attr_count = struct.unpack_from("<IIHHH", data, body)
                element = Element(strings[name])
                for index in range(attr_count):
                    a = body + attr_start + index * attr_size
                    _a_ns, a_name, raw, _vsize, _res0, vtype, vdata = struct.unpack_from("<IIIHBBI", data, a)
                    key = strings[a_name] if a_name < len(strings) else ""
                    if not key and a_name < len(resource_ids):
                        key = ATTR_IDS.get(resource_ids[a_name], f"0x{resource_ids[a_name]:08x}")
                    element.attrs[key] = _axml_value(strings, raw, vtype, vdata)
                if stack:
                    stack[-1].children.append(element)
                else:
                    root = element
                stack.append(element)
            elif chunk_type == _RES_XML_END_ELEMENT_TYPE and stack:
                stack.pop()
            at += chunk_size
    except (struct.error, IndexError) as error:
        raise ManifestError(f"broken binary XML: {error}") from error
    if root is None:
        raise ManifestError("binary XML has no elements")
    return root


def _axml_value(strings: list[str], raw: int, vtype: int, vdata: int) -> str:
    if raw != _NO_INDEX and raw < len(strings):
        return strings[raw]
    if vtype == _TYPE_STRING and vdata < len(strings):
        return strings[vdata]
    if vtype == _TYPE_INT_BOOLEAN:
        return "true" if vdata else "false"
    if vtype == _TYPE_INT_DEC:
        return str(struct.unpack("<i", struct.pack("<I", vdata))[0])
    if vtype == _TYPE_INT_HEX:
        return f"0x{vdata:x}"
    return str(vdata)


# --- aapt2 protobuf XML, as inside an AAB ----------------------------------------------------------
# Only the fields this check needs (aapt2's Resources.proto): XmlNode{1 element}; XmlElement{3 name,
# 4 attribute, 5 child}; XmlAttribute{2 name, 3 value, 5 resource_id, 6 compiled_item};
# Item{2 str, 3 raw_str, 7 prim}; String/RawString{1 value}; Primitive{6 int_decimal, 7 int_hex, 8 boolean}.


def _varint(data: bytes, at: int) -> tuple[int, int]:
    value = 0
    shift = 0
    while True:
        if at >= len(data):
            raise ManifestError("truncated protobuf")
        byte = data[at]
        at += 1
        value |= (byte & 0x7F) << shift
        if not byte & 0x80:
            return value, at
        shift += 7


def _fields(data: bytes) -> list[tuple[int, int | bytes]]:
    """(field number, value) for every field: an int for varints and fixed, bytes for length-delimited."""
    found: list[tuple[int, int | bytes]] = []
    at = 0
    while at < len(data):
        key, at = _varint(data, at)
        number, wire = key >> 3, key & 7
        if wire == 0:
            value, at = _varint(data, at)
            found.append((number, value))
        elif wire == 2:
            length, at = _varint(data, at)
            if at + length > len(data):
                raise ManifestError("truncated protobuf")
            found.append((number, data[at:at + length]))
            at += length
        elif wire == 5:
            found.append((number, struct.unpack_from("<I", data, at)[0]))
            at += 4
        elif wire == 1:
            found.append((number, struct.unpack_from("<Q", data, at)[0]))
            at += 8
        else:
            raise ManifestError(f"unsupported protobuf wire type {wire}")
    return found


def _text(value: int | bytes) -> str:
    return value.decode("utf-8", errors="replace") if isinstance(value, bytes) else str(value)


def _proto_item(data: bytes) -> str:
    for number, value in _fields(data):
        if number in (2, 3) and isinstance(value, bytes):
            for inner, text in _fields(value):
                if inner == 1:
                    return _text(text)
        if number == 7 and isinstance(value, bytes):
            for inner, prim in _fields(value):
                if inner == 8 and isinstance(prim, int):
                    return "true" if prim else "false"
                if inner == 6 and isinstance(prim, int):
                    return str(prim - (1 << 64) if prim >= 1 << 63 else prim)
                if inner == 7 and isinstance(prim, int):
                    return f"0x{prim:x}"
    return ""


def _proto_element(data: bytes) -> Element:
    element = Element("")
    for number, value in _fields(data):
        if number == 3:
            element.tag = _text(value)
        elif number == 4 and isinstance(value, bytes):
            name, text, compiled, resource_id = "", "", "", 0
            for a_number, a_value in _fields(value):
                if a_number == 2:
                    name = _text(a_value)
                elif a_number == 3:
                    text = _text(a_value)
                elif a_number == 5 and isinstance(a_value, int):
                    resource_id = a_value
                elif a_number == 6 and isinstance(a_value, bytes):
                    compiled = _proto_item(a_value)
            if not name and resource_id:
                name = ATTR_IDS.get(resource_id, f"0x{resource_id:08x}")
            element.attrs[name] = text if text else compiled
        elif number == 5 and isinstance(value, bytes):
            for n_number, n_value in _fields(value):
                if n_number == 1 and isinstance(n_value, bytes):
                    element.children.append(_proto_element(n_value))
    return element


def parse_proto_xml(data: bytes) -> Element:
    try:
        for number, value in _fields(data):
            if number == 1 and isinstance(value, bytes):
                root = _proto_element(value)
                if root.tag:
                    return root
    except (struct.error, IndexError) as error:
        raise ManifestError(f"broken protobuf XML: {error}") from error
    raise ManifestError("protobuf XML has no root element")


# --- Reading a build -------------------------------------------------------------------------------


def _tool(env_name: str, command: str) -> str | None:
    configured = os.environ.get(env_name, "")
    if configured and Path(configured).exists():
        return configured
    return shutil.which(command)


def _bundletool_manifest(path: Path) -> str | None:
    tool = _tool("BUNDLETOOL", "bundletool")
    if tool is None:
        return None
    command = ["java", "-jar", tool] if tool.endswith(".jar") else [tool]
    result = subprocess.run([*command, "dump", "manifest", "--bundle", str(path)], capture_output=True, text=True, check=False)
    return result.stdout if result.returncode == 0 and result.stdout.strip() else None


def aapt2_permissions(path: Path) -> list[str] | None:
    """Permissions `aapt2 dump permissions` reports for an APK, or None when aapt2 is not available."""
    tool = _tool("AAPT2", "aapt2")
    if tool is None:
        return None
    result = subprocess.run([tool, "dump", "permissions", str(path)], capture_output=True, text=True, check=False)
    if result.returncode != 0:
        return None
    found: list[str] = []
    for line in result.stdout.splitlines():
        if "permission:" in line or "uses-permission" in line:
            for token in line.replace("'", " ").replace("=", " ").split():
                if "." in token and "permission" in token.lower():
                    found.append(token)
    return found


def parse_bytes(data: bytes) -> Element:
    if is_axml(data):
        return parse_axml(data)
    stripped = data.lstrip()
    if stripped.startswith(b"<"):
        return parse_text_xml(data.decode("utf-8", errors="replace"))
    return parse_proto_xml(data)


def load_manifest(path: Path) -> Element:
    if not path.is_file():
        raise ManifestError(f"{path} does not exist")
    suffix = path.suffix.lower()
    if suffix in (".aab", ".apk", ".zip"):
        try:
            with zipfile.ZipFile(path) as archive:
                names = set(archive.namelist())
                if suffix == ".aab" or AAB_MANIFEST in names:
                    dumped = _bundletool_manifest(path) if suffix == ".aab" else None
                    if dumped is not None:
                        return parse_text_xml(dumped)
                    if AAB_MANIFEST not in names:
                        raise ManifestError(f"{path} has no {AAB_MANIFEST}")
                    return parse_proto_xml(archive.read(AAB_MANIFEST))
                if APK_MANIFEST not in names:
                    raise ManifestError(f"{path} has no {APK_MANIFEST}")
                return parse_bytes(archive.read(APK_MANIFEST))
        except zipfile.BadZipFile as error:
            raise ManifestError(f"{path} is not a zip archive") from error
    return parse_bytes(path.read_bytes())


# --- The checks ------------------------------------------------------------------------------------


def permissions(manifest: Element) -> list[str]:
    return [e.attrs.get("name", "") for e in manifest.iter() if e.tag in PERMISSION_TAGS]


def check(manifest: Element, require_smallest_width: int | None = None, extra_permissions: list[str] | None = None) -> list[str]:
    """Every problem found, as one sentence each (empty when the manifest passes)."""
    problems: list[str] = []
    if manifest.tag != "manifest":
        problems.append(f"the root element is <{manifest.tag}>, not <manifest>")
    asked = set(permissions(manifest)) | set(extra_permissions or [])
    for banned in BANNED_PERMISSIONS:
        if banned in asked:
            problems.append(f"banned permission requested: {banned}")
    screens = [e for e in manifest.iter() if e.tag == "supports-screens"]
    if not screens:
        problems.append("no <supports-screens>: phones are not excluded")
    attrs: dict[str, str] = {}
    for element in screens:
        attrs.update(element.attrs)  # several elements: the last value wins, as on the device
    if screens:
        for name in ("smallScreens", "normalScreens"):
            if attrs.get(name, "true").lower() != "false":
                problems.append(f'<supports-screens android:{name}> must be "false" (phones excluded), found {attrs.get(name, "missing (defaults to true)")}')
        width = attrs.get("requiresSmallestWidthDp")
        if width is not None:
            try:
                if int(width, 0) < SMALLEST_WIDTH_DP:
                    problems.append(f"android:requiresSmallestWidthDp is {width}, below {SMALLEST_WIDTH_DP}")
            except ValueError:
                problems.append(f"android:requiresSmallestWidthDp is not a number: {width}")
        elif require_smallest_width is not None:
            problems.append(f"android:requiresSmallestWidthDp is missing (required: {require_smallest_width})")
        if width is not None and require_smallest_width is not None:
            try:
                if int(width, 0) < require_smallest_width:
                    problems.append(f"android:requiresSmallestWidthDp is {width}, below the required {require_smallest_width}")
            except ValueError:
                pass
    return problems


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("path", type=Path, help=".aab, .apk or AndroidManifest.xml (plain or binary)")
    parser.add_argument("--require-smallest-width", type=int, default=None, metavar="DP", help="also require android:requiresSmallestWidthDp >= DP")
    args = parser.parse_args(argv)
    try:
        manifest = load_manifest(args.path)
    except ManifestError as error:
        print(f"check_manifest: cannot read {args.path}: {error}", file=sys.stderr)
        return 2
    extra = aapt2_permissions(args.path) if args.path.suffix.lower() == ".apk" else None
    asked = sorted(set(permissions(manifest)) | set(extra or []))
    print(f"check_manifest: {args.path}")
    print(f"  permissions: {', '.join(asked) if asked else '(none)'}")
    if extra is not None:
        print("  (aapt2 dump permissions was read as well)")
    problems = check(manifest, args.require_smallest_width, extra)
    for problem in problems:
        print(f"  FAIL {problem}")
    if problems:
        return 1
    print("  OK: no banned permission; phones excluded")
    return 0


if __name__ == "__main__":
    sys.exit(main())
