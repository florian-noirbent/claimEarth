"""Slice the player reference painting into cutout-rig parts.

Reads assets/objects/player/source/reference.png and writes one PNG per body part
plus parts.json (placement, pivot, parent, draw order) into source/template, and a
labelled overview of the parts to source/parts_sheet.png. The output is the redraw
template; the textures the game uses come from tools/extract_player_parts.py.
Areas a part hides behind another part are filled with a flat sampled colour and a
dark outline, so each part is a complete redraw template. The far (left) arm and
leg are tinted copies of the near ones.

Usage: python tools/slice_player_reference.py [--debug-dir DIR]
Requires Pillow, NumPy and SciPy.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage

REPO_ROOT = Path(__file__).resolve().parent.parent
PLAYER_DIR = REPO_ROOT / "assets" / "objects" / "player"
SOURCE_DIR = PLAYER_DIR / "source"
REFERENCE_PATH = SOURCE_DIR / "reference.png"
TEMPLATE_DIR = SOURCE_DIR / "template"

SUPERSAMPLE = 4
PADDING = 2
OUTLINE_COLOR = (24, 14, 7)
OUTLINE_WIDTH = 3.0
SAMPLE_RADIUS = 3

# Named colour sample points in reference pixels.
SAMPLES = {
	"skin": (165, 209),
	"shirt": (200, 290),
	"backpack": (30, 300),
	"belt": (175, 350),
	"trousers": (140, 480),
	"boot": (120, 585),
	"arm_skin": (110, 355),
	"glove": (120, 420),
}

# Parts are listed in claim order: an opaque reference pixel belongs to the first
# part whose "cut" polygons contain it, so later polygons can be generous.
#   cut    - polygons of reference pixels this part owns.
#   hidden - extra polygons completing the silhouette behind other parts.
#   fills  - (sample name, polygon or None for the whole part) painted in order
#            under the reference pixels.
#   pivot  - joint position in reference pixels.
#   z      - draw order, back to front.
PARTS = [
	{
		"name": "head",
		"parent": "torso",
		"pivot": (165, 200),
		"z": 8,
		"cut": [[
			(0, 0), (308, 0), (308, 212), (234, 212), (226, 212.5), (205, 212.5),
			(186, 209), (166, 201), (154, 190), (148, 199), (118, 199), (95, 190),
			(60, 182), (0, 182),
		]],
		"hidden": [],
		"fills": [],
	},
	{
		"name": "scarf",
		"parent": "torso",
		"pivot": (165, 215),
		"z": 7,
		"cut": [[
			(117, 199), (141, 200), (151, 205), (186, 222), (186, 208), (191, 211),
			(207, 222), (222, 237), (226, 262), (226, 272), (207, 279), (195, 270),
			(180, 251), (165, 233), (150, 223), (118, 216),
		]],
		"hidden": [],
		"fills": [],
	},
	{
		"name": "upper_arm",
		"parent": "torso",
		"pivot": (130, 250),
		"z": 11,
		"cut": [[
			(101, 240), (110, 231), (125, 227), (141, 232), (152, 243), (160, 260),
			(161, 280), (153, 300), (148, 310), (151, 318), (151, 336), (146, 347),
			(138, 343), (90, 341), (84, 346), (78, 341), (78, 318), (81, 311),
			(88, 300), (95, 285), (98, 262),
		]],
		"hidden": [],
		"fills": [],
	},
	{
		"name": "forearm",
		"parent": "upper_arm",
		"pivot": (115, 330),
		"z": 10,
		"cut": [[
			(86, 339), (142, 339), (140, 372), (149, 374), (150, 399), (125, 402),
			(88, 403), (85, 378), (93, 373), (90, 345),
		]],
		"hidden": [[(93, 322), (135, 322), (140, 345), (90, 345)]],
		"fills": [("arm_skin", None)],
	},
	{
		"name": "hand",
		"parent": "forearm",
		"pivot": (118, 398),
		"z": 9,
		"cut": [[
			(85, 399), (150, 396), (155, 408), (160, 425), (159, 442), (152, 453),
			(140, 457), (125, 459), (105, 455), (92, 449), (86, 432), (85, 410),
		]],
		"hidden": [[(90, 390), (146, 390), (150, 400), (86, 402)]],
		"fills": [("glove", None)],
	},
	{
		"name": "pelvis",
		"parent": "",
		"pivot": (160, 370),
		"z": 6,
		"cut": [[
			(138, 337), (228, 337), (228, 400), (196, 400), (188, 402), (186, 418),
			(180, 424), (150, 424), (138, 400),
		]],
		"hidden": [[
			(106, 337), (215, 337), (214, 400), (196, 402), (186, 424), (150, 424),
			(120, 412), (106, 395),
		]],
		"fills": [
			("trousers", None),
			("belt", [(100, 337), (230, 337), (230, 365), (100, 365)]),
		],
	},
	{
		"name": "boot",
		"parent": "shin",
		"pivot": (130, 545),
		"z": 3,
		"cut": [[
			(70, 543), (110, 543), (110, 549), (170, 549), (168, 560), (172, 571),
			(186, 579), (195, 592), (199, 600), (200, 621), (70, 621),
		]],
		"hidden": [[(92, 525), (166, 525), (170, 549), (88, 549)]],
		"fills": [("boot", None)],
	},
	{
		"name": "shin",
		"parent": "thigh",
		"pivot": (140, 462),
		"z": 4,
		"cut": [[
			(74, 462), (185, 462), (183, 470), (178, 490), (172, 505), (173, 549),
			(110, 549), (110, 543), (74, 543),
		]],
		"hidden": [[(104, 442), (190, 442), (185, 462), (102, 462)]],
		"fills": [("trousers", None)],
	},
	{
		"name": "thigh",
		"parent": "pelvis",
		"pivot": (145, 390),
		"z": 5,
		"cut": [[
			(98, 385), (200, 385), (196, 400), (193, 420), (190, 440), (185, 462),
			(98, 462),
		]],
		"hidden": [[
			(100, 385), (198, 385), (196, 400), (190, 440), (184, 472), (170, 478),
			(110, 478), (104, 462), (104, 440), (100, 400),
		]],
		"fills": [("trousers", None)],
	},
	{
		"name": "torso",
		"parent": "pelvis",
		"pivot": (160, 340),
		"z": 2,
		"cut": [[
			(118, 199), (140, 199), (140, 185), (230, 185), (232, 338), (143, 338), (143, 350), (100, 350),
			(100, 232), (106, 222), (118, 216),
		]],
		"hidden": [
			[
				(112, 222), (125, 212), (150, 206), (190, 214), (204, 225), (216, 237),
				(217, 275), (211, 285), (212, 320), (214, 350), (108, 350), (105, 300), (106, 250),
			],
			[(148, 185), (180, 185), (188, 209), (186, 221), (150, 208), (140, 201)],
		],
		"fills": [
			("shirt", None),
			("skin", [(148, 185), (180, 185), (188, 209), (186, 221), (150, 208), (140, 201)]),
		],
	},
	{
		"name": "backpack",
		"parent": "torso",
		"pivot": (105, 250),
		"z": 1,
		"cut": [[
			(0, 190), (118, 199), (118, 216), (106, 222), (100, 232), (100, 420),
			(0, 420),
		]],
		"hidden": [[
			(80, 206), (112, 203), (124, 212), (128, 240), (128, 330), (122, 362),
			(105, 380), (85, 386),
		]],
		"fills": [("backpack", None)],
	},
]

# The far (left) limbs are tinted copies of the near limbs, so the visible slivers
# of the far leg in the reference are intentionally left unclaimed.
UNCLAIMED_ALLOWED = [[
	(165, 396), (260, 396), (260, 621), (165, 621),
]]

# Far limbs: (source part, parent, z, offset). Each copy is named "<source>_left",
# moved by its offset in reference pixels, and multiplied by FAR_TINT. The leg
# offsets grow toward the foot to match the forward far leg of the reference.
FAR_TINT = (0.66, 0.66, 0.74)
FAR_ARM_OFFSET = (22, -2)
FAR_LIMBS = [
	("hand", "forearm_left", -6, FAR_ARM_OFFSET),
	("forearm", "upper_arm_left", -5, FAR_ARM_OFFSET),
	("upper_arm", "torso", -4, FAR_ARM_OFFSET),
	("boot", "shin_left", -3, (55, -6)),
	("shin", "thigh_left", -2, (40, -4)),
	("thigh", "pelvis", -1, (20, -2)),
]


def polygon_coverage(polygons: list, size: tuple[int, int]) -> np.ndarray:
	"""Returns antialiased 0..1 coverage of the union of polygons."""
	width, height = size
	canvas = Image.new("L", (width * SUPERSAMPLE, height * SUPERSAMPLE), 0)
	draw = ImageDraw.Draw(canvas)
	for polygon in polygons:
		draw.polygon(
			[(x * SUPERSAMPLE, y * SUPERSAMPLE) for x, y in polygon], fill=255
		)
	canvas = canvas.resize(size, Image.BOX)
	return np.asarray(canvas, dtype=np.float32) / 255.0


def sample_color(reference: np.ndarray, point: tuple[int, int]) -> np.ndarray:
	x, y = point
	patch = reference[
		y - SAMPLE_RADIUS:y + SAMPLE_RADIUS + 1,
		x - SAMPLE_RADIUS:x + SAMPLE_RADIUS + 1,
		:3,
	]
	return np.median(patch.reshape(-1, 3), axis=0)


def build_part(part: dict, reference: np.ndarray, owned: np.ndarray) -> np.ndarray:
	"""Returns the full-canvas RGBA float image of one part."""
	height, width = owned.shape
	size = (width, height)
	visible_alpha = np.where(owned, reference[:, :, 3], 0.0)
	result = np.zeros((height, width, 4), dtype=np.float32)

	if part["fills"]:
		# The silhouette is the hidden polygons plus everything the part owns.
		hidden_coverage = polygon_coverage(part["hidden"], size)
		silhouette = np.maximum(hidden_coverage, (visible_alpha > 0.5).astype(np.float32))
		color = np.zeros((height, width, 3), dtype=np.float32)
		for sample_name, polygon in part["fills"]:
			fill_color = sample_color(reference, SAMPLES[sample_name])
			region = np.ones((height, width), dtype=bool)
			if polygon is not None:
				region = polygon_coverage([polygon], size) >= 0.5
			color[region] = fill_color
		depth = ndimage.distance_transform_edt(silhouette >= 0.5)
		outline = np.clip(OUTLINE_WIDTH + 0.5 - depth, 0.0, 1.0)[:, :, None]
		color = color * (1.0 - outline) + np.asarray(OUTLINE_COLOR, dtype=np.float32) * outline
		result[:, :, :3] = color
		result[:, :, 3] = silhouette * 255.0

	# Reference pixels composite over the fill.
	source_alpha = (visible_alpha / 255.0)[:, :, None]
	under_alpha = (result[:, :, 3] / 255.0)[:, :, None]
	out_alpha = source_alpha + under_alpha * (1.0 - source_alpha)
	blended = reference[:, :, :3] * source_alpha + result[:, :, :3] * under_alpha * (1.0 - source_alpha)
	result[:, :, :3] = np.divide(blended, out_alpha, out=np.zeros_like(blended), where=out_alpha > 0)
	result[:, :, 3] = out_alpha[:, :, 0] * 255.0
	return result


def far_copy(image: np.ndarray, offset: tuple[int, int]) -> np.ndarray:
	"""Returns a tinted copy of a full-canvas part image moved by offset."""
	height, width = image.shape[:2]
	offset_x, offset_y = offset
	moved = np.zeros_like(image)
	source = image[max(-offset_y, 0):height - max(offset_y, 0), max(-offset_x, 0):width - max(offset_x, 0)]
	moved[max(offset_y, 0):max(offset_y, 0) + source.shape[0], max(offset_x, 0):max(offset_x, 0) + source.shape[1]] = source
	moved[:, :, :3] *= np.asarray(FAR_TINT, dtype=np.float32)
	return moved


def crop_bounds(image: np.ndarray) -> tuple[int, int, int, int]:
	rows = np.flatnonzero(image[:, :, 3].max(axis=1) > 0)
	columns = np.flatnonzero(image[:, :, 3].max(axis=0) > 0)
	height, width = image.shape[:2]
	return (
		max(int(columns[0]) - PADDING, 0),
		max(int(rows[0]) - PADDING, 0),
		min(int(columns[-1]) + 1 + PADDING, width),
		min(int(rows[-1]) + 1 + PADDING, height),
	)


def to_image(array: np.ndarray) -> Image.Image:
	return Image.fromarray(np.clip(array + 0.5, 0, 255).astype(np.uint8), "RGBA")


def write_debug(debug_dir: Path, reference: np.ndarray, parts: list, images: dict, claims: np.ndarray) -> None:
	debug_dir.mkdir(parents=True, exist_ok=True)
	height, width = claims.shape
	ordered = sorted(parts, key=lambda part: part["z"])

	assembled = Image.new("RGBA", (width, height), (0, 0, 0, 0))
	for part in ordered:
		assembled.alpha_composite(to_image(images[part["name"]]))
	assembled.save(debug_dir / "assembled.png")

	palette = np.random.default_rng(7).integers(60, 255, size=(len(PARTS) + 1, 3))
	overlay = reference[:, :, :3] * 0.45 + palette[claims] * 0.55
	overlay[claims == 0] = reference[claims == 0, :3]
	overlay[(claims == 0) & (reference[:, :, 3] > 0)] = (255, 0, 255)
	overlay[reference[:, :, 3] == 0] = (40, 40, 40)
	Image.fromarray(overlay.astype(np.uint8), "RGB").resize(
		(width * 3, height * 3), Image.NEAREST
	).save(debug_dir / "claims.png")


def write_sheet(path: Path, parts: list, images: dict) -> None:
	"""Writes a labelled overview of every part with its pivot marked."""
	crops = []
	for part in parts:
		image = images[part["name"]]
		left, top, right, bottom = crop_bounds(image)
		crops.append((part, to_image(image[top:bottom, left:right]), (left, top)))
	columns = 4
	cell_width = max(crop.width for _, crop, _ in crops) + 24
	cell_height = max(crop.height for _, crop, _ in crops) + 40
	rows = (len(crops) + columns - 1) // columns
	sheet = Image.new("RGBA", (cell_width * columns, cell_height * rows), (70, 110, 140, 255))
	draw = ImageDraw.Draw(sheet)
	for index, (part, crop, origin) in enumerate(crops):
		x = (index % columns) * cell_width + 12
		y = (index // columns) * cell_height + 28
		sheet.alpha_composite(crop, (x, y))
		pivot_x = x + part["pivot"][0] - origin[0]
		pivot_y = y + part["pivot"][1] - origin[1]
		draw.ellipse((pivot_x - 4, pivot_y - 4, pivot_x + 4, pivot_y + 4), outline=(255, 40, 40, 255), width=2)
		draw.text((x, y - 22), part["name"], fill=(255, 255, 255, 255))
	sheet.save(path)


def main() -> None:
	parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
	parser.add_argument("--debug-dir", type=Path, help="write claim overlay and reassembled preview here")
	arguments = parser.parse_args()

	reference = np.asarray(Image.open(REFERENCE_PATH).convert("RGBA"), dtype=np.float32)
	height, width = reference.shape[:2]
	size = (width, height)
	opaque = reference[:, :, 3] > 0

	claims = np.zeros((height, width), dtype=np.int32)
	for index, part in enumerate(PARTS, start=1):
		cut = polygon_coverage(part["cut"], size) >= 0.5
		claims[cut & opaque & (claims == 0)] = index

	allowed = polygon_coverage(UNCLAIMED_ALLOWED, size) >= 0.5
	stray = int(np.count_nonzero(opaque & (claims == 0) & ~allowed))
	if stray:
		print(f"warning: {stray} opaque reference pixels belong to no part")

	parts = []
	images = {}
	for index, part in enumerate(PARTS, start=1):
		parts.append(part)
		images[part["name"]] = build_part(part, reference, claims == index)
	near = {part["name"]: part for part in PARTS}
	for source_name, parent, z, offset in FAR_LIMBS:
		pivot = near[source_name]["pivot"]
		name = f"{source_name}_left"
		parts.append({
			"name": name,
			"parent": parent,
			"pivot": (pivot[0] + offset[0], pivot[1] + offset[1]),
			"z": z,
		})
		images[name] = far_copy(images[source_name], offset)

	TEMPLATE_DIR.mkdir(parents=True, exist_ok=True)
	manifest = {"reference_size": [width, height], "parts": []}
	for part in parts:
		image = images[part["name"]]
		left, top, right, bottom = crop_bounds(image)
		to_image(image[top:bottom, left:right]).save(TEMPLATE_DIR / f"{part['name']}.png")
		manifest["parts"].append({
			"name": part["name"],
			"texture": f"{part['name']}.png",
			"parent": part["parent"],
			"z": part["z"],
			"origin": [left, top],
			"size": [right - left, bottom - top],
			"pivot": list(part["pivot"]),
		})
		print(f"{part['name']}: {right - left}x{bottom - top} at ({left}, {top})")

	manifest["parts"].sort(key=lambda entry: entry["z"])
	(TEMPLATE_DIR / "parts.json").write_text(json.dumps(manifest, indent="\t") + "\n", encoding="utf-8")

	write_sheet(SOURCE_DIR / "parts_sheet.png", parts, images)
	if arguments.debug_dir:
		write_debug(arguments.debug_dir, reference, parts, images, claims)


if __name__ == "__main__":
	main()
