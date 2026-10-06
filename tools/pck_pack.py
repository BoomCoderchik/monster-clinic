#!/usr/bin/env python3
"""Упаковка проекта Godot в PCK без запуска редактора.

Повторяет формат, который пишет PCKPacker из ядра Godot 4
(`core/io/pck_packer.cpp`, PACK_FORMAT_VERSION = 4  # PACK_FORMAT_VERSION_V4 — формат каталога, который пишет PCKPacker в Godot 4.x).

Зачем нужен: если официальный редактор Godot недоступен (например, в CI или в
изолированной среде), PCK для Web-сборки можно собрать этим скриптом и
положить рядом с официальным Web-шаблоном движка. Текстовые `project.godot` и
`*.tscn` движок читает и в шаблонных сборках, поэтому дополнительной
компиляции ресурсов не требуется.

Пример:

    python3 tools/pck_pack.py --project . --output web/index.pck

"""
from __future__ import annotations

import argparse
import hashlib
import os
import struct
import sys

PACK_HEADER_MAGIC = 0x43504447  # "GDPC"
PACK_FORMAT_VERSION = 4  # PACK_FORMAT_VERSION_V4 — формат каталога, который пишет PCKPacker в Godot 4.x
PACK_REL_FILEBASE = 1 << 1
PACK_FILE_ENCRYPTED = 1 << 0
PACK_FILE_REMOVAL = 1 << 1
ALIGNMENT = 32

# Каталоги, которые не попадают в сборку (совпадает с exclude_filter в export_presets.cfg).
EXCLUDED_DIRS = {".godot", ".git", "web", "tests", "tools", "__pycache__"}
EXCLUDED_FILES = {"export_presets.cfg", "run-tests.sh", "run-web-preview.sh", "README.md", "concept.md"}


def _pad(alignment: int, value: int) -> int:
    rest = value % alignment
    return 0 if rest == 0 else alignment - rest


def iter_project_files(project_root: str, include_tests: bool = False) -> list[tuple[str, str]]:
    """Возвращает список (res-путь, путь на диске) для PCK."""
    result: list[tuple[str, str]] = []
    for dirpath, dirnames, filenames in os.walk(project_root):
        excluded = EXCLUDED_DIRS - {"tests"} if include_tests else EXCLUDED_DIRS
        dirnames[:] = sorted(d for d in dirnames if d not in excluded)
        for name in sorted(filenames):
            if name in EXCLUDED_FILES:
                continue
            full_path = os.path.join(dirpath, name)
            rel_path = os.path.relpath(full_path, project_root).replace(os.sep, "/")
            result.append((rel_path, full_path))
    result.sort(key=lambda item: item[0])
    return result


def build_pck(entries: list[tuple[str, bytes]], output_path: str) -> None:
    """Собирает PCK из списка (путь в res://, содержимое)."""
    buffer = bytearray()

    def write(data: bytes) -> None:
        buffer.extend(data)

    write(struct.pack("<I", PACK_HEADER_MAGIC))
    write(struct.pack("<I", PACK_FORMAT_VERSION))
    write(struct.pack("<I", 4))  # major
    write(struct.pack("<I", 7))  # minor
    write(struct.pack("<I", 2))  # patch
    write(struct.pack("<I", PACK_REL_FILEBASE))

    file_base_offset = len(buffer)
    write(struct.pack("<Q", 0))  # file_base, заполним позже
    dir_offset_position = len(buffer)
    write(struct.pack("<Q", 0))  # directory offset, заполним позже
    write(b"\x00" * (16 * 4))  # reserved

    write(b"\x00" * _pad(ALIGNMENT, len(buffer)))
    file_base = len(buffer)

    directory: list[tuple[str, int, int, bytes]] = []
    for path, data in entries:
        write(b"\x00" * _pad(ALIGNMENT, len(buffer)))
        offset = len(buffer)
        write(data)
        directory.append((path, offset - file_base, len(data), hashlib.md5(data).digest()))

    write(b"\x00" * _pad(ALIGNMENT, len(buffer)))
    dir_offset = len(buffer)
    write(struct.pack("<I", len(directory)))
    for path, offset, size, digest in directory:
        encoded = path.encode("utf-8")
        padding = _pad(4, len(encoded))
        write(struct.pack("<I", len(encoded) + padding))
        write(encoded)
        write(b"\x00" * padding)
        write(struct.pack("<Q", offset))
        write(struct.pack("<Q", size))
        write(digest)
        write(struct.pack("<I", 0))

    struct.pack_into("<Q", buffer, file_base_offset, file_base)
    struct.pack_into("<Q", buffer, dir_offset_position, dir_offset)

    os.makedirs(os.path.dirname(os.path.abspath(output_path)) or ".", exist_ok=True)
    with open(output_path, "wb") as handle:
        handle.write(buffer)


def pack_project(project_root: str, output_path: str, include_tests: bool = False) -> list[str]:
    entries: list[tuple[str, bytes]] = []
    packed_paths: list[str] = []
    for rel_path, full_path in iter_project_files(project_root, include_tests):
        with open(full_path, "rb") as handle:
            entries.append((rel_path, handle.read()))
        packed_paths.append(rel_path)
    build_pck(entries, output_path)
    return packed_paths


def main() -> int:
    parser = argparse.ArgumentParser(description="Собрать PCK проекта без редактора Godot.")
    parser.add_argument("--project", default=".", help="каталог проекта с project.godot")
    parser.add_argument("--output", default="web/index.pck", help="куда положить .pck")
    parser.add_argument("--include-tests", action="store_true", help="включить tests/ (для headless-прогонов)")
    args = parser.parse_args()

    if not os.path.isfile(os.path.join(args.project, "project.godot")):
        print(f"Нет project.godot в {args.project}", file=sys.stderr)
        return 1

    packed = pack_project(args.project, args.output, args.include_tests)
    size = os.path.getsize(args.output)
    print(f"{args.output}: {len(packed)} файлов, {size} байт")
    for path in packed:
        print(f"  + {path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
