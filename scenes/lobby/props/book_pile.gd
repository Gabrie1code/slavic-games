class_name BookPile
extends Node3D
## Стопка книг, где каждая книга — своё физическое тело (Tippable). Сбили табурет —
## книги разлетаются и падают по-настоящему; когда табурет вернулся на место, книги
## возвращаются на него (Tippable.support). Раньше стопка была одной неподвижной моделью
## и «висела в воздухе», когда табурет падал.

const COLORS: Array[Color] = [Color("992018"), Color("cc9918"), Color("26262e"),
	Color("4d8c99"), Color("e8dcc0"), Color("2a6a2a"), Color("b85a1a")]
const PAGES := Color("f2ead2")


## Сложить count книг стопкой; support — на чём стоит стопка (табурет), может быть null.
## Узел уже должен стоять на месте (position) — книги запоминают «дом» при появлении.
func build(count: int, support: Tippable, seed_value: int = 33) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var y := 0.0
	for i in count:
		var size := Vector3(rng.randf_range(0.17, 0.24), rng.randf_range(0.038, 0.05),
			rng.randf_range(0.12, 0.16))
		var book := Tippable.new()
		book.setup_model(_book_model(size, COLORS[(i * 3) % COLORS.size()]), size,
			size.y / 2.0, 0.4)
		book.support = support
		book.position = Vector3(rng.randf_range(-0.02, 0.02), y, rng.randf_range(-0.02, 0.02))
		book.rotation.y = rng.randf_range(-0.35, 0.35)
		# Тонкая быстрая книга за один шаг физики «ныряла» в пол глубже своей толщины и
		# застревала в нём — непрерывная проверка столкновений ловит касание вовремя.
		book.continuous_cd = true
		book.can_sleep = true
		book.sleeping = true # лежит спокойно, пока стопку не тронули
		add_child(book)
		y += size.y


## Книга: обложка цвета color и светлый срез страниц с трёх сторон (обложка чуть больше).
static func _book_model(size: Vector3, color: Color) -> Node3D:
	var root := Node3D.new()
	var cover := 0.005
	root.add_child(_box(Vector3(size.x, cover, size.z), Vector3(0, cover / 2.0, 0), color))
	root.add_child(_box(Vector3(size.x, cover, size.z), Vector3(0, size.y - cover / 2.0, 0), color))
	# Корешок слева, страницы — внутри обложек, чуть короче их.
	root.add_child(_box(Vector3(cover, size.y, size.z), Vector3(-size.x / 2.0 + cover / 2.0,
		size.y / 2.0, 0), color))
	root.add_child(_box(Vector3(size.x - cover - 0.006, size.y - cover * 2.0, size.z - 0.008),
		Vector3(cover / 2.0 - 0.003, size.y / 2.0, 0), PAGES))
	return root


static func _box(size: Vector3, pos: Vector3, color: Color) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_instance.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.85
	mesh_instance.material_override = mat
	mesh_instance.position = pos
	return mesh_instance
