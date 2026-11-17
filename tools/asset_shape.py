"""Is it the right shape, with the right number of parts, before more time is spent on it?

Used by tools/asset_generate.py. Two failures kept coming back in the package notes:

- Proportions. A sofa briefed at 22 studs long came out 15, a gallery wall 2:1, a hedge as
  tall columns. Each was found after the mesh was made and built. The brief now holds length,
  width and height, and they are checked twice: loosely on the reference picture, strictly on
  the draft mesh.
- Counts. Four paintings instead of three, five seats instead of eight, a tail rotor with
  four blades on one seed and six on the next. The brief now lists what must be counted, and
  whoever chooses a picture or a mesh has to write down what they counted.

What the picture check can and cannot do, measured on 19 packages on 2026-11-16: the camera
angle of a reference is not known, so the outline's width over height only bounds the
proportions. The sofa's picture (3.45 wide per high) fits both the 22-stud brief and the
15-stud result. It does catch a subject that is tall where the brief is long, which is how
whole reference rounds were lost. The mesh check is exact, and costs one 512 draft.
"""

import math
import re

# A draft mesh may differ from the brief by this share of each dimension, or half a stud.
PROPORTION_TOLERANCE = 0.2
PROPORTION_MIN_STUDS = 0.5
# A reference is drawn "front three-quarter view from slightly above": the camera is assumed
# to be somewhere in these ranges, and the outline is allowed this much slack on top.
VIEW_YAW = (10, 60)
VIEW_PITCH = (5, 30)
IMAGE_SLACK = 0.15
BACKGROUND_DIFFERENCE = 40  # summed RGB distance from the corner colour that counts as subject


def target(brief):
    """(long side, short side, height) in studs from the brief, or None if it does not say."""
    length, width, height = brief.get("lengthStuds"), brief.get("widthStuds"), brief.get("heightStuds")
    if not (length and width and height):
        return None
    return max(length, width), min(length, width), height


def image_aspect(path):
    """Width over height of the subject's outline in a picture on a plain background."""
    import numpy as np
    from PIL import Image

    pixels = np.asarray(Image.open(path).convert("RGB")).astype(int)
    corners = np.concatenate([pixels[:8, :8], pixels[:8, -8:], pixels[-8:, :8], pixels[-8:, -8:]]).reshape(-1, 3)
    subject = np.abs(pixels - np.median(corners, axis=0)).sum(2) > BACKGROUND_DIFFERENCE
    rows, cols = np.where(subject)
    if not len(cols):
        return None
    return float((cols.max() - cols.min() + 1) / (rows.max() - rows.min() + 1))


def image_bounds(long_side, short_side, height):
    """The narrowest and widest outline a box of this size can have from a reference camera."""
    found = []
    for yaw in range(VIEW_YAW[0], VIEW_YAW[1] + 1, 5):
        for pitch in range(VIEW_PITCH[0], VIEW_PITCH[1] + 1, 5):
            a, p = math.radians(yaw), math.radians(pitch)
            across = long_side * math.cos(a) + short_side * math.sin(a)
            up = height * math.cos(p) + (long_side * math.sin(a) + short_side * math.cos(a)) * math.sin(p)
            found.append(across / up)
    return min(found) * (1 - IMAGE_SLACK), max(found) * (1 + IMAGE_SLACK)


def image_problem(path, brief):
    """(aspect, low, high, problem or None) for a reference picture against the brief."""
    wanted = target(brief)
    aspect = image_aspect(path)
    if not wanted or aspect is None:
        return aspect, None, None, None
    low, high = image_bounds(*wanted)
    problem = None
    if aspect < low:
        problem = f"the subject is {aspect:.2f} wide per high; a {wanted[0]:g} x {wanted[1]:g} x {wanted[2]:g} stud object cannot look narrower than {low:.2f}. It is too tall or too short end to end"
    elif aspect > high:
        problem = f"the subject is {aspect:.2f} wide per high; a {wanted[0]:g} x {wanted[1]:g} x {wanted[2]:g} stud object cannot look wider than {high:.2f}. It is too long or too low"
    return aspect, low, high, problem


def mesh_studs(size, brief):
    """(long side, short side) in studs once the mesh is scaled to the brief's height. `size` is z-up."""
    scale = brief["heightStuds"] / size[2]
    return max(size[0], size[1]) * scale, min(size[0], size[1]) * scale


def mesh_problems(size, brief):
    """What is wrong with a mesh's proportions against the brief, in plain words. Empty when fine."""
    wanted = target(brief)
    if not wanted or not size or size[2] <= 0:
        return []
    out = []
    for label, got, want in zip(("long", "deep"), mesh_studs(size, brief), wanted[:2]):
        if abs(got - want) > max(want * PROPORTION_TOLERANCE, PROPORTION_MIN_STUDS):
            out.append(f"{got:.1f} studs {label} at the brief's height, where the brief says {want:g}")
    return out


def parse_counts(items, flag):
    """['seats=8', 'legs=4'] -> {'seats': 8, 'legs': 4}. ['none'] -> {}."""
    counts = {}
    for item in items or ():
        if item.strip().lower() == "none":
            continue
        found = re.fullmatch(r"\s*([A-Za-z][A-Za-z0-9 _-]*?)\s*=\s*(\d+)\s*", item)
        if not found:
            raise ValueError(f"{flag} takes name=number, e.g. {flag} seats=8 (or {flag} none), got {item!r}")
        counts[found.group(1).lower()] = int(found.group(2))
    return counts


def count_problems(wanted, counted):
    """(names not counted yet, ['seats: 5, the brief says 8', ...])."""
    missing = [name for name in wanted if name not in counted]
    wrong = [f"{name}: {counted[name]}, the brief says {number}" for name, number in wanted.items() if name in counted and counted[name] != number]
    return missing, wrong
