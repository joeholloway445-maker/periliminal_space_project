extends SceneTree
## Headless generator: 40 casino cat-skin portraits (20 races × m/f) into
## res://assets/characters/casino_skins/<race>_<m|f>.jpg.
## Run: godot --headless --path . -s res://src/dev/gen_casino_skins.gd
## The portraits are flat-shaded front-facing cat heads: race fur color,
## sex differences (m: broad jaw + brows; f: lashes + blush), markings per
## race, and a race-glow arc so they read as game art, not photos.

const S := 512

## Cat-breed id → Omni Dex slug (mirrors IdentityArt.ALIASES). Casino skin
## files are named by Omni Dex slug: <slug>_m.jpg / <slug>_f.jpg.
const BREED_TO_DEX := {
	"tabby": "lumenari", "siamese": "gutterkin", "maine_coon": "deepborne",
	"persian": "ashen_choir", "bengal": "veilstriders", "russian_blue": "chronarchs",
	"sphynx": "nullborn", "ragdoll": "thorned", "scottish_fold": "echoes",
	"abyssinian": "hollowed", "burmese": "riftspawn", "turkish_angora": "mirekin",
	"norwegian_forest": "sunspun", "birman": "coldmarrow", "tonkinese": "pulseborn",
	"devon_rex": "dreamflesh", "oriental": "crownless", "somali": "rotweavers",
	"manx": "glassborn", "savannah": "starfall",
}

func _init() -> void:
	var made := 0
	const RDC := preload("res://src/character/race_data_character.gd")
	var out_dir := "res://assets/characters/casino_skins"
	DirAccess.make_dir_recursive_absolute(out_dir)
	for race: Dictionary in RDC.RACES:
		var slug: String = BREED_TO_DEX.get(str(race.get("id", "")), str(race.get("id", "")))
		for sex: String in ["m", "f"]:
			var img := _draw_cat(race, sex)
			var path := "%s/%s_%s.jpg" % [out_dir, slug, sex]
			var err := img.save_jpg(path, 0.9)
			if err == OK:
				made += 1
				print("wrote ", path)
			else:
				push_error("Failed to write %s (err %d)" % [path, err])
	print("CASINO_SKINS_DONE total=", made)
	quit()

func _draw_cat(race: Dictionary, sex: String) -> Image:
	var img := Image.create(S, S, false, Image.FORMAT_RGB8)
	var fur: Color = race.get("primary_color", Color(0.6, 0.5, 0.4))
	var outline: Color = fur.darkened(0.6)
	var fur_hi: Color = fur.lightened(0.3)
	var muzzle: Color = fur.lightened(0.4)
	var inner_ear := Color(0.98, 0.72, 0.72)
	var iris := _iris_color(str(race.get("id", "")))
	var blush := Color(0.95, 0.5, 0.55)
	var is_f := sex == "f"
	var head_rx := 148.0 * (0.94 if is_f else 1.06)
	var head_ry := 165.0
	var cx := 256.0
	var cy := 300.0

	# Background + soft radial glow behind the head.
	img.fill_rect(Rect2i(0, 0, S, S), Color(0.045, 0.035, 0.08))
	var glow_r := head_rx * 1.75
	for y in range(int(cy - glow_r), int(cy + glow_r)):
		for x in range(int(cx - glow_r), int(cx + glow_r)):
			if x < 0 or y < 0 or x >= S or y >= S:
				continue
			var dx := float(x) - cx
			var dy := float(y) - cy
			var d := sqrt(dx * dx + dy * dy)
			if d <= glow_r:
				var t := 1.0 - d / glow_r
				var base := Color(0.045, 0.035, 0.08)
				img.set_pixel(x, y, base.lerp(fur.darkened(0.35), t * t * 0.55))

	# Ears (triangles) behind the head.
	_draw_triangle(img, Vector2(cx - 150, 205), Vector2(cx - 60, 95), Vector2(cx - 30, 175), fur)
	_draw_triangle(img, Vector2(cx + 150, 205), Vector2(cx + 60, 95), Vector2(cx + 30, 175), fur)
	_draw_triangle(img, Vector2(cx - 132, 190), Vector2(cx - 72, 122), Vector2(cx - 52, 172), inner_ear)
	_draw_triangle(img, Vector2(cx + 132, 190), Vector2(cx + 72, 122), Vector2(cx + 52, 172), inner_ear)

	# Head.
	_draw_ellipse(img, cx, cy, head_rx, head_ry, fur)
	# Jaw tufts (male = broader).
	if not is_f:
		_draw_triangle(img, Vector2(cx - head_rx * 0.98, cy + 52), Vector2(cx - head_rx * 1.28, cy + 92), Vector2(cx - head_rx * 0.7, cy + 96), fur)
		_draw_triangle(img, Vector2(cx + head_rx * 0.98, cy + 52), Vector2(cx + head_rx * 1.28, cy + 92), Vector2(cx + head_rx * 0.7, cy + 96), fur)

	# Muzzle + nose.
	_draw_ellipse(img, cx, cy + 58, 66, 48, muzzle)
	_draw_triangle(img, Vector2(cx - 12, cy + 32), Vector2(cx + 12, cy + 32), Vector2(cx, cy + 52), Color(0.95, 0.6, 0.62))
	# Mouth.
	_draw_line(img, Vector2(cx - 12, cy + 56), Vector2(cx - 30, cy + 66), outline, 4)
	_draw_line(img, Vector2(cx + 12, cy + 56), Vector2(cx + 30, cy + 66), outline, 4)

	# Whiskers (longer on males).
	var wlen := 118.0 if not is_f else 96.0
	for i in 4:
		var dy := 8.0 * float(i - 1)
		_draw_line(img, Vector2(cx - 58, cy + 56 + dy), Vector2(cx - 58 - wlen, cy + 44 + dy), Color(1, 1, 1, 0.8), 3)
		_draw_line(img, Vector2(cx + 58, cy + 56 + dy), Vector2(cx + 58 + wlen, cy + 44 + dy), Color(1, 1, 1, 0.8), 3)

	# Eyes.
	var eye_y := cy - 8.0
	var eye_rx := 27.0 if is_f else 25.0
	var eye_ry := 27.0 if is_f else 22.0
	for ex in [cx - 86.0, cx + 86.0]:
		_draw_ellipse(img, ex, eye_y, eye_rx, eye_ry, Color(0.97, 0.97, 0.99))
		_draw_ellipse(img, ex, eye_y + 2, eye_rx * 0.78, eye_ry * 0.78, iris)
		_draw_ellipse(img, ex, eye_y + 2, eye_rx * 0.3, eye_ry * 0.55, Color(0.06, 0.05, 0.06))
		_draw_circle(img, ex - eye_rx * 0.28, eye_y - eye_ry * 0.28, 4.5, Color(1, 1, 1))
		if is_f:
			# Lashes.
			for li in 3:
				var lx: float = ex - eye_rx * 0.7 + float(li) * eye_rx * 0.7
				_draw_line(img, Vector2(lx, eye_y - eye_ry * 0.85), Vector2(lx + 6, eye_y - eye_ry * 1.35), outline, 3)
		else:
			# Thick brows.
			_draw_rect_rounded(img, Rect2(ex - eye_rx * 1.1, eye_y - eye_ry - 16, eye_rx * 2.2, 9), outline)

	# Forehead markings.
	var id := str(race.get("id", ""))
	if id in ["tabby", "bengal", "savannah", "somali", "abyssinian", "maine_coon", "norwegian_forest"]:
		for si in 3:
			var sx := cx - 34.0 + si * 34.0
			_draw_rect_rounded(img, Rect2(sx, cy - head_ry * 0.78, 16, 58), outline)
	elif id in ["burmese", "tonkinese", "devon_rex", "manx", "scottish_fold", "russian_blue"]:
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(id)
		for si in 8:
			_draw_circle(img, cx - 60 + rng.randf() * 120.0, cy - head_ry * 0.72 + rng.randf() * 46.0, 7.0 + rng.randf() * 5.0, outline)

	# Female blush.
	if is_f:
		_draw_ellipse(img, cx - 84, cy + 34, 22, 13, blush)
		_draw_ellipse(img, cx + 84, cy + 34, 22, 13, blush)

	# Race-glow arc behind the head.
	var arc_r := head_rx + 16.0
	for a in range(200, 340):
		var rad := deg_to_rad(float(a))
		var ax := cx + cos(rad) * arc_r
		var ay := cy + sin(rad) * arc_r
		_draw_circle(img, ax, ay, 3.2, fur_hi)

	return img

func _iris_color(race_id: String) -> Color:
	match race_id:
		"siamese", "russian_blue", "turkish_angora": return Color(0.35, 0.5, 0.85)
		"bengal", "savannah", "abyssinian", "somali": return Color(0.55, 0.72, 0.3)
		"persian", "ragdoll", "birman": return Color(0.75, 0.6, 0.9)
		"oriental", "burmese", "tonkinese": return Color(0.95, 0.85, 0.5)
		"sphynx", "devon_rex": return Color(0.3, 0.85, 0.8)
		_: return Color(0.85, 0.55, 0.25)

func _draw_circle(img: Image, cx: float, cy: float, r: float, col: Color) -> void:
	var r2 := r * r
	for y in range(int(cy - r), int(cy + r) + 1):
		for x in range(int(cx - r), int(cx + r) + 1):
			if x < 0 or y < 0 or x >= S or y >= S:
				continue
			var dx := float(x) - cx
			var dy := float(y) - cy
			if dx * dx + dy * dy <= r2:
				img.set_pixel(x, y, col)

func _draw_ellipse(img: Image, cx: float, cy: float, rx: float, ry: float, col: Color) -> void:
	for y in range(int(cy - ry), int(cy + ry) + 1):
		for x in range(int(cx - rx), int(cx + rx) + 1):
			if x < 0 or y < 0 or x >= S or y >= S:
				continue
			var dx := (float(x) - cx) / rx
			var dy := (float(y) - cy) / ry
			if dx * dx + dy * dy <= 1.0:
				img.set_pixel(x, y, col)

func _draw_triangle(img: Image, a: Vector2, b: Vector2, c: Vector2, col: Color) -> void:
	var min_x := int(minf(a.x, minf(b.x, c.x)))
	var max_x := int(maxf(a.x, maxf(b.x, c.x)))
	var min_y := int(minf(a.y, minf(b.y, c.y)))
	var max_y := int(maxf(a.y, maxf(b.y, c.y)))
	for y in range(min_y, max_y + 1):
		for x in range(min_x, max_x + 1):
			var p := Vector2(float(x) + 0.5, float(y) + 0.5)
			if _point_in_triangle(p, a, b, c):
				img.set_pixel(x, y, col)

func _point_in_triangle(p: Vector2, a: Vector2, b: Vector2, c: Vector2) -> bool:
	var d1 := _sign(p, a, b)
	var d2 := _sign(p, b, c)
	var d3 := _sign(p, c, a)
	var has_neg := d1 < 0 or d2 < 0 or d3 < 0
	var has_pos := d1 > 0 or d2 > 0 or d3 > 0
	return not (has_neg and has_pos)

func _sign(p1: Vector2, p2: Vector2, p3: Vector2) -> float:
	return (p1.x - p3.x) * (p2.y - p3.y) - (p2.x - p3.x) * (p1.y - p3.y)

func _draw_line(img: Image, a: Vector2, b: Vector2, col: Color, width: int) -> void:
	var steps := int(maxf(absf(b.x - a.x), absf(b.y - a.y))) + 1
	for i in steps + 1:
		var t := float(i) / float(steps)
		var p := a.lerp(b, t)
		_draw_circle(img, p.x, p.y, float(width) * 0.5, col)

func _draw_rect_rounded(img: Image, rect: Rect2, col: Color) -> void:
	for y in range(int(rect.position.y), int(rect.position.y + rect.size.y)):
		for x in range(int(rect.position.x), int(rect.position.x + rect.size.x)):
			if x >= 0 and y >= 0 and x < S and y < S:
				img.set_pixel(x, y, col)
