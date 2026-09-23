#!/usr/bin/env bash
set -eu

sertos_dir=../sertos
library="$sertos_dir/lib/posix/libsertos_posix.a"
build_dir=build/posix
target="$build_dir/sertos_gaussian_demo"

sources=(
    src/main.c
    src/gaussian_math.c
    src/gaussian_state.c
    src/gaussian_tasks.c
    src/terminal_ui.c
    src/bsp/bsp_console_posix.c
)

includes=(
    -Iinc
    -I"$sertos_dir/inc"
    -I"$sertos_dir/port"
    -I"$sertos_dir/modules/ring_buffer"
    -I"$sertos_dir/modules/linked_list"
    -I"$sertos_dir/modules/bitmap"
    -I"$sertos_dir/modules/atomic"
)

for tool in gcc ar size; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        echo "[ERROR] POSIX demo build requires $tool in WSL." >&2
        exit 1
    fi
done

echo "[TOOLCHAIN] gcc=$(command -v gcc)"
echo "[TOOLCHAIN] ar=$(command -v ar)"
echo "[TOOLCHAIN] size=$(command -v size)"

if [[ ! -f "$library" ]]; then
    echo "[BUILD] SertOS POSIX library not found; building it first..."
    (
        cd "$sertos_dir"
        ./build.sh
    )
fi

if [[ ! -f "$library" ]]; then
    echo "[ERROR] SertOS POSIX library was not generated: $library" >&2
    exit 1
fi

mkdir -p "$build_dir"
echo "[BUILD] Compiling $target"
gcc -O2 -Wall -Wextra -pedantic -std=c99 "${includes[@]}" \
    "${sources[@]}" "$library" -pthread -lm -o "$target"

echo "[SUCCESS] Generated: $target"
size -A "$target" | grep -E '^(\.text|\.data|\.bss|Total)' || true
