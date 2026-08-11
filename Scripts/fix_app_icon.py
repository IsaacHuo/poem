#!/usr/bin/env python3
"""Remove a baked white outer mask from an iOS app icon.

Only near-white pixels connected to the canvas edge are replaced. Light artwork
inside the icon remains untouched. The replacement samples the nearest artwork
pixel on a ray toward the image centre and feathers the repaired boundary.
"""

from __future__ import annotations

import argparse
from collections import deque
from pathlib import Path

from PIL import Image, ImageFilter


def is_outer_white(pixel: tuple[int, int, int]) -> bool:
    red, green, blue = pixel
    return min(pixel) >= 225 and max(pixel) - min(pixel) <= 16


def connected_outer_mask(image: Image.Image) -> bytearray:
    width, height = image.size
    pixels = image.load()
    mask = bytearray(width * height)
    queue: deque[tuple[int, int]] = deque()

    def enqueue(x: int, y: int) -> None:
        index = y * width + x
        if not mask[index] and is_outer_white(pixels[x, y]):
            mask[index] = 1
            queue.append((x, y))

    for x in range(width):
        enqueue(x, 0)
        enqueue(x, height - 1)
    for y in range(height):
        enqueue(0, y)
        enqueue(width - 1, y)

    while queue:
        x, y = queue.popleft()
        if x > 0:
            enqueue(x - 1, y)
        if x + 1 < width:
            enqueue(x + 1, y)
        if y > 0:
            enqueue(x, y - 1)
        if y + 1 < height:
            enqueue(x, y + 1)

    return mask


def repair_icon(source: Path, destination: Path) -> None:
    image = Image.open(source).convert("RGB")
    width, height = image.size
    if width != height:
        raise ValueError(f"App icon must be square, got {width}×{height}")

    mask = connected_outer_mask(image)
    repaired = image.copy()
    source_pixels = image.load()
    repaired_pixels = repaired.load()
    for y in range(height):
        for x in range(width):
            if not mask[y * width + x]:
                continue

            candidates: list[tuple[int, tuple[int, int, int]]] = []
            for distance in range(1, width):
                found = False
                for sample_x, sample_y in (
                    (x - distance, y),
                    (x + distance, y),
                    (x, y - distance),
                    (x, y + distance),
                ):
                    if not (0 <= sample_x < width and 0 <= sample_y < height):
                        continue
                    if not mask[sample_y * width + sample_x]:
                        candidates.append((distance, source_pixels[sample_x, sample_y]))
                        found = True
                if found and len(candidates) >= 2:
                    break

            if candidates:
                nearest = sorted(candidates, key=lambda candidate: candidate[0])[:2]
                weights = [1 / max(distance, 1) for distance, _ in nearest]
                total_weight = sum(weights)
                repaired_pixels[x, y] = tuple(
                    round(sum(pixel[channel] * weight for weight, (_, pixel) in zip(weights, nearest)) / total_weight)
                    for channel in range(3)
                )

    mask_image = Image.new("L", image.size)
    mask_image.putdata([255 if value else 0 for value in mask])
    feathered_mask = mask_image.filter(ImageFilter.GaussianBlur(radius=3))
    softened_repair = repaired.filter(ImageFilter.GaussianBlur(radius=5))
    result = Image.composite(softened_repair, image, feathered_mask)
    result.save(destination, format="PNG", optimize=True)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path)
    parser.add_argument("destination", type=Path, nargs="?")
    args = parser.parse_args()

    destination = args.destination or args.source
    repair_icon(args.source, destination)
    print(f"Wrote {destination}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
