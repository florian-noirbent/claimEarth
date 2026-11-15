"""Extract the player cutout-rig textures from the redrawn parts sheet.

Reads assets/objects/player/source/parts_redraw.png, a repaint of
source/parts_sheet.png that keeps its 4-column cell layout, and writes one tightly
cropped PNG per body part into assets/objects/player. Labels and stray specks are
dropped by keeping only the largest opaque shape in each cell.

Usage: python tools/extract_player_parts.py
Requires Pillow, NumPy and SciPy.
"""

from __future__ import annotations

from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage

REPO_ROOT = Path(__file__).resolve().parent.parent
PLAYER_DIR = REPO_ROOT / "assets" / "objects" / "player"
SHEET_PATH = PLAYER_DIR / "source" / "parts_redraw.png"

COLUMNS = 4
# Sheet cells in reading order.
PART_NAMES = [
	"head", "scarf", "upper_arm", "forearm",
	"hand", "pelvis", "boot", "shin",
	"thigh", "torso", "backpack", "hand_left",
	"forearm_left", "upper_arm_left", "boot_left", "shin_left",
	"thigh_left",
]
# The redrawn torso already includes the scarf, so its own cell is not exported.
UNUSED_PARTS = {"scarf"}
SOLID_ALPHA = 40
EDGE_GROW = 2
# Transparent margin around each part, which the rig's outline shader draws into.
# tools/build_player_rig.gd repeats it as TEXTURE_MARGIN.
PADDING = 32
# The game draws the character about 25 screen pixels tall, so the painted colors are
# pushed apart to stay readable: above 1 the saturation is stronger, and below 1 the
# gamma lifts the dark browns away from the cave colors.
SATURATION = 1.35
GAMMA = 0.78
LUMA = np.array([0.299, 0.587, 0.114])


def main() -> None:
	sheet = np.asarray(Image.open(SHEET_PATH).convert("RGBA"))
	height, width = sheet.shape[:2]
	rows = (len(PART_NAMES) + COLUMNS - 1) // COLUMNS
	cell_width = width / COLUMNS
	cell_height = height / rows

	labels, count = ndimage.label(sheet[:, :, 3] > SOLID_ALPHA)
	sizes = ndimage.sum(sheet[:, :, 3] > SOLID_ALPHA, labels, range(1, count + 1))
	centers = ndimage.center_of_mass(sheet[:, :, 3] > SOLID_ALPHA, labels, range(1, count + 1))

	largest: dict[int, int] = {}
	for index in range(count):
		center_y, center_x = centers[index]
		cell = int(center_y // cell_height) * COLUMNS + int(center_x // cell_width)
		if cell not in largest or sizes[index] > sizes[largest[cell]]:
			largest[cell] = index

	for cell, name in enumerate(PART_NAMES):
		if name in UNUSED_PARTS:
			continue
		if cell not in largest:
			raise SystemExit(f"no art found in the sheet cell for {name}")
		# Growing the solid shape keeps its antialiased rim without the loose halo.
		shape = ndimage.binary_dilation(labels == largest[cell] + 1, iterations=EDGE_GROW)
		part = _graded(sheet)
		part[~shape] = 0
		rows_used = np.flatnonzero(shape.any(axis=1))
		columns_used = np.flatnonzero(shape.any(axis=0))
		left, right = int(columns_used[0]), int(columns_used[-1]) + 1
		top, bottom = int(rows_used[0]), int(rows_used[-1]) + 1
		# The margin is added around the crop, so it never depends on the sheet edges.
		padded = np.zeros((bottom - top + 2 * PADDING, right - left + 2 * PADDING, 4), dtype=np.uint8)
		padded[PADDING:-PADDING, PADDING:-PADDING] = part[top:bottom, left:right]
		Image.fromarray(padded, "RGBA").save(PLAYER_DIR / f"{name}.png")
		print(f"{name}: {padded.shape[1]}x{padded.shape[0]}")


def _graded(sheet: np.ndarray) -> np.ndarray:
	"""Returns the sheet with the readability color grade applied."""
	color = sheet[:, :, :3].astype(np.float64) / 255.0
	luma = (color @ LUMA)[:, :, None]
	color = np.clip(luma + (color - luma) * SATURATION, 0.0, 1.0) ** GAMMA
	graded = sheet.copy()
	graded[:, :, :3] = np.round(color * 255.0).astype(np.uint8)
	return graded


if __name__ == "__main__":
	main()
