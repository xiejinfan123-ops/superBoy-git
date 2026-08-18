"""Cut the player character into the pieces the leg rig animates.

    python tools/cut_character_layers.py

Regenerates C/char_torso.png, C/char_leg_far.png and C/char_leg_near.png from
C/char_body_no_cape.png — the character with the cape already removed and the
previously-covered torso painted in, so the cape can be simulated as its own
cloth layer (C/char_cape.png) behind him. Safe to re-run; it only ever writes
those three files.

This is a positional cut, not a colour one. Below the hips his two legs occupy
completely separate columns with a wide gap between them, so slicing by
coordinate is exact and needs no image reconstruction — unlike the cape, which
overlaps his body and therefore needs artwork rather than a script.

The torso and the legs must not share any pixels. An earlier version kept a
17 px band of leg on the torso, reasoning that it would hide each leg's cut
edge. It did the opposite: that band stays still while the leg swings away
from it, so the leg's outline visibly breaks at the hip on every step. The
pieces are therefore cut on exactly the same line, and the leg's squared top
is hidden because it sits behind his body, which is far wider than the leg
there. What does get exposed is a wedge a few pixels tall at full swing —
about 0.4 px once the sprite is scaled into the game.
"""

from __future__ import annotations

import sys
from pathlib import Path

from PIL import Image, ImageDraw

ART = Path(__file__).resolve().parent.parent / "C"
SOURCE = ART / "char_body_no_cape.png"

# Measured from the source: the legs resolve into two clean separate spans at
# y=1715, and the gap between them never closes above x=1085.
HIP_CUT_Y = 1715
LEG_SPLIT_X = 1085
LEG_LEFT_X = 840
LEG_RIGHT_X = 1340

# Pivots sit just inside the torso so each leg swings from under it.
HIP_FAR = (926, 1720)
HIP_NEAR = (1141, 1720)


def box_mask(size: tuple[int, int], box: tuple[int, int, int, int]) -> Image.Image:
    mask = Image.new("L", size, 0)
    ImageDraw.Draw(mask).rectangle(box, fill=255)
    return mask


def apply(source: Image.Image, mask: Image.Image) -> Image.Image:
    out = source.copy()
    out.putalpha(Image.composite(source.getchannel("A"),
                                 Image.new("L", source.size, 0), mask))
    return out


def main() -> int:
    if not SOURCE.exists():
        print(f"missing source: {SOURCE}")
        return 1

    source = Image.open(SOURCE).convert("RGBA")
    size = source.size

    far = box_mask(size, (LEG_LEFT_X, HIP_CUT_Y, LEG_SPLIT_X, size[1]))
    near = box_mask(size, (LEG_SPLIT_X + 1, HIP_CUT_Y, LEG_RIGHT_X, size[1]))
    torso_cut = box_mask(size, (LEG_LEFT_X, HIP_CUT_Y, LEG_RIGHT_X, size[1]))
    torso_keep = torso_cut.point(lambda v: 255 - v)

    pieces = {
        "char_leg_far.png": apply(source, far),
        "char_leg_near.png": apply(source, near),
        "char_torso.png": apply(source, torso_keep),
    }
    for name, img in pieces.items():
        img.save(ART / name)
        print(f"  wrote {name:20s} bbox={img.getchannel('A').getbbox()}")

    # Stacking the pieces back in draw order must reproduce the source exactly,
    # or the rig is animating something that no longer matches the artwork.
    stacked = Image.new("RGBA", size, (0, 0, 0, 0))
    for name in ("char_leg_far.png", "char_leg_near.png", "char_torso.png"):
        stacked = Image.alpha_composite(stacked, pieces[name])

    src_op = source.getchannel("A").point(lambda v: 1 if v > 128 else 0)
    out_op = stacked.getchannel("A").point(lambda v: 1 if v > 128 else 0)
    lost = sum(1 for a, b in zip(src_op.get_flattened_data(),
                                 out_op.get_flattened_data()) if a and not b)
    print(f"\n  pixels lost when the pieces are stacked back: {lost}")
    if lost:
        print("  FAIL — the cut is dropping artwork")
        return 1
    print("  OK — the cut is lossless")
    print(f"\n  hip pivots: far={HIP_FAR} near={HIP_NEAR} (source pixel coords)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
