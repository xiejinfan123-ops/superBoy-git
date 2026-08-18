"""Acceptance checker for the cape/body layer split.

Run it yourself before declaring the task done:

    python tools/check_cape_layers.py

Exits 0 when every check passes, 1 otherwise. Requires Pillow only.

The layers exist so the cape can be rotated independently at runtime. That is
the whole point, and it is why "looks identical when stacked at rest" is not
sufficient — a raw alpha cutout passes that and still falls apart the moment
anything moves.
"""

from __future__ import annotations

import sys
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw

ART = Path(__file__).resolve().parent.parent / "C"
SOURCE = ART / "1786820354134.png"
CAPE = ART / "char_cape.png"
BODY = ART / "char_body_no_cape.png"
UNDER_BODY = ART / "char_body_under_cape.png"

PIVOT = (1080, 950)
ROTATIONS = (10.0, -10.0)
STRAIGHT_RUN_LIMIT = 30
RECOMPOSE_TOLERANCE = 12000

failures: list[str] = []


def check(label: str, ok: bool, detail: str) -> None:
    print(f"  [{'PASS' if ok else 'FAIL'}] {label}: {detail}")
    if not ok:
        failures.append(label)


def silhouette(img: Image.Image) -> Image.Image:
    return img.getchannel("A").point(lambda v: 255 if v > 128 else 0)


def opaque_pixels(mask: Image.Image) -> int:
    return sum(v > 128 for v in mask.getdata())


def stack(under: Image.Image, over: Image.Image) -> Image.Image:
    base = Image.new("RGBA", under.size, (0, 0, 0, 0))
    return Image.alpha_composite(Image.alpha_composite(base, under), over)


def differing_pixels(a: Image.Image, b: Image.Image, threshold: int = 40) -> int:
    diff = ImageChops.difference(a.convert("RGB"), b.convert("RGB")).convert("L")
    return sum(diff.histogram()[threshold:])


def enclosed_holes(mask: Image.Image) -> int:
    """Transparent pixels completely surrounded by opaque ones — always a tear."""
    w, h = mask.size
    flood = mask.point(lambda v: 255 - v)
    for corner in ((0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1)):
        ImageDraw.floodfill(flood, corner, 128)
    return sum(1 for v in flood.point(lambda v: 1 if v == 255 else 0).getdata() if v)


def longest_straight_edge(mask: Image.Image) -> int:
    """Longest run of rows whose silhouette edge sits at an identical x.

    A drawn contour wanders by a pixel or two constantly. A long perfectly
    straight edge means the shape was cut by a rectangle rather than drawn,
    which is exactly what shows up as a hard seam once the piece moves.
    """
    w, h = mask.size
    px = mask.load()
    worst = 0
    for side in ("left", "right"):
        run = 0
        previous = None
        for y in range(h):
            edge = None
            rng = range(w) if side == "left" else range(w - 1, -1, -1)
            for x in rng:
                if px[x, y]:
                    edge = x
                    break
            if edge is not None and edge == previous:
                run += 1
                worst = max(worst, run)
            else:
                run = 0
            previous = edge
    return worst


def main() -> int:
    for path in (SOURCE, CAPE, BODY, UNDER_BODY):
        if not path.exists():
            print(f"missing required file: {path}")
            return 1

    source = Image.open(SOURCE).convert("RGBA")
    cape = Image.open(CAPE).convert("RGBA")
    body = Image.open(BODY).convert("RGBA")
    under_body = Image.open(UNDER_BODY).convert("RGBA")

    print("\n1. Canvas size and alignment")
    check("cape canvas", cape.size == source.size, f"{cape.size} vs source {source.size}")
    check("body canvas", body.size == source.size, f"{body.size} vs source {source.size}")
    check("under-body canvas", under_body.size == source.size,
          f"{under_body.size} vs source {source.size}")

    print("\n2. Stacking the two layers reproduces the original")
    print("   (cape belongs BEHIND the body: his belly overlaps the cape in the source)")
    behind = differing_pixels(stack(cape, body), source)
    front = differing_pixels(stack(body, cape), source)
    print(f"         cape behind body: {behind} px differ")
    print(f"         cape in front:    {front} px differ")
    check("recomposition", behind <= RECOMPOSE_TOLERANCE,
          f"{behind} px differ with the cape behind, tolerance {RECOMPOSE_TOLERANCE}")

    print("\n3. Each layer is a complete drawing, not a cutout")
    print("   (a drawn contour never runs perfectly straight for long)")
    for name, layer in (("cape", cape), ("body", body)):
        run = longest_straight_edge(silhouette(layer))
        check(f"{name} has no machine-cut edge", run < STRAIGHT_RUN_LIMIT,
              f"longest straight edge {run} px, limit {STRAIGHT_RUN_LIMIT}")

    print("\n4. Nothing tears when the cape moves")
    for angle in ROTATIONS:
        rotated = cape.rotate(angle, center=PIVOT, resample=Image.BICUBIC)
        holes = enclosed_holes(silhouette(stack(rotated, body)))
        check(f"no holes at {angle:+.0f} deg", holes < 200, f"{holes} px of enclosed hole")

    print("\n5. The foreground body alone still reads as the whole character")
    body_holes = enclosed_holes(silhouette(body))
    check("body has no internal tear", body_holes < 200, f"{body_holes} px of enclosed hole")

    print("\n6. The cape has a real, complete body underneath it")
    source_mask = silhouette(source)
    body_mask = silhouette(body)
    under_mask = silhouette(under_body)
    added_pixels = opaque_pixels(under_mask) - opaque_pixels(body_mask)
    check("under-body adds the cape-covered torso", added_pixels >= 100000,
          f"{added_pixels} new opaque px, need at least 100000")
    outside_source = ImageChops.multiply(under_mask, ImageChops.invert(source_mask))
    check("under-body preserves resting silhouette", opaque_pixels(outside_source) == 0,
          f"{opaque_pixels(outside_source)} px outside original character")

    # This is the regression that the old checker was missing. At each wide
    # swing, look only at pixels that were cape at rest, are no longer cape or
    # foreground body, and belong to the concealed torso. Those pixels must be
    # supplied by the fixed under-body layer, never by transparent background.
    for angle in (25.0, -25.0):
        moved = cape.rotate(angle, center=PIVOT, resample=Image.BICUBIC)
        moved_mask = silhouette(moved)
        foreground_mask = ImageChops.lighter(moved_mask, body_mask)
        newly_exposed = ImageChops.multiply(
            under_mask, ImageChops.subtract(silhouette(cape), foreground_mask))
        exposed_count = opaque_pixels(newly_exposed)
        composed = stack(stack(under_body, moved), body)
        transparent_exposure = ImageChops.multiply(
            newly_exposed, ImageChops.invert(silhouette(composed)))
        check(f"under-body is exposed at {angle:+.0f} deg", exposed_count >= 5000,
              f"{exposed_count} px newly exposed, need at least 5000")
        check(f"no transparent torso at {angle:+.0f} deg",
              opaque_pixels(transparent_exposure) == 0,
              f"{opaque_pixels(transparent_exposure)} transparent exposed px")

    print()
    if failures:
        print(f"FAILED {len(failures)} check(s): {', '.join(failures)}")
        return 1
    print("All checks passed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
