extends PanelContainer

@onready var stock_list: VBoxContainer = %StockList
@onready var alert_list: VBoxContainer = %AlertList

var _visible_panel: bool = false
var _product_totals: Dictionary = {}
var _shelf_max_total: int = 0

const LOW_RATIO := 0.3
const COL_OK := Color(0.3, 0.9, 0.4)
const COL_LOW := Color(1.0, 0.85, 0.25)
const COL_EMPTY := Color(1.0, 0.35, 0.35)
const COL_TEXT := Color(0.78, 0.78, 0.82)
const COL_MUTED := Color(0.5, 0.5, 0.55)

func _ready() -> void:
	visible = false
	EventBus.shelf_stock_changed.connect(_on_shelf_stock_changed)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_panel"):
		_toggle()
		get_viewport().set_input_as_handled()

func _toggle() -> void:
	_visible_panel = not _visible_panel
	if _visible_panel:
		visible = true
		modulate.a = 0.0
		_rebuild_ui()
		var tw := create_tween()
		tw.tween_property(self, "modulate:a", 1.0, 0.15)
	else:
		var tw := create_tween()
		tw.tween_property(self, "modulate:a", 0.0, 0.1)
		tw.tween_callback(func(): visible = false)

func _on_shelf_stock_changed(shelf: Node, product_id: String, _current: int, _max_stock: int, _side_name: String) -> void:
	_recalculate_from_shelves()
	if _visible_panel:
		_rebuild_ui()

func _recalculate_from_shelves() -> void:
	_product_totals.clear()
	_shelf_max_total = 0
	var shelves := get_tree().get_nodes_in_group("shelves")
	for shelf in shelves:
		if not shelf.has_method("get_total_stock"):
			continue
		if shelf.has_method("get_total_max"):
			_shelf_max_total += shelf.get_total_max()
		if "stock" in shelf and shelf.stock is Dictionary:
			for side_key in shelf.stock:
				var sd = shelf.stock[side_key]
				if sd is Dictionary:
					for pid in sd:
						var c: int = sd[pid]
						if c > 0:
							_product_totals[pid] = _product_totals.get(pid, 0) + c

func _rebuild_ui() -> void:
	_clear(stock_list)
	_clear(alert_list)

	var db = get_node_or_null("/root/ProductDatabase")
	var grand: int = 0
	for v in _product_totals.values():
		grand += v

	var gr: float = float(grand) / float(_shelf_max_total) if _shelf_max_total > 0 else 0.0
	_add_row(stock_list, "Total Inventory", "%d / %d" % [grand, _shelf_max_total], _ratio_color(gr, grand), true)
	_add_bar(stock_list, grand, _shelf_max_total, gr)
	_add_sep(stock_list)

	var pids: Array = _product_totals.keys()
	pids.sort()
	for pid in pids:
		var c: int = _product_totals[pid]
		var pname: String = pid.capitalize()
		if db:
			var p = db.get_product(pid)
			if p and "product_name" in p:
				pname = p.product_name
		var col: Color = COL_EMPTY if c <= 1 else (COL_LOW if c <= 3 else COL_OK)
		_add_row(stock_list, pname, str(c), col, false)

	if _product_totals.is_empty():
		var lbl := Label.new()
		lbl.text = "No stock on shelves"
		lbl.add_theme_color_override("font_color", COL_MUTED)
		lbl.add_theme_font_size_override("font_size", 13)
		stock_list.add_child(lbl)

	_add_sep(stock_list)

	var shelves := get_tree().get_nodes_in_group("shelves")
	for shelf in shelves:
		if not shelf.has_method("get_total_stock"):
			continue
		var tags: Array[String] = []
		if shelf.has_method("get_all_tags"):
			tags = shelf.get_all_tags()
		var tag: String = tags[0].capitalize() if not tags.is_empty() else "?"
		var ts: int = shelf.get_total_stock()
		var tm: int = shelf.get_total_max() if shelf.has_method("get_total_max") else 10
		var r: float = float(ts) / float(tm) if tm > 0 else 0.0
		_add_row(stock_list, tag, "%d/%d" % [ts, tm], _ratio_color(r, ts), false)

	_rebuild_alerts(db)

func _rebuild_alerts(db) -> void:
	for pid in _product_totals:
		var c: int = _product_totals[pid]
		if c > 3:
			continue
		var pname: String = pid.capitalize()
		if db:
			var p = db.get_product(pid)
			if p and "product_name" in p:
				pname = p.product_name
		var a := Label.new()
		if c <= 0:
			a.text = "⚠ %s — EMPTY" % pname
			a.add_theme_color_override("font_color", COL_EMPTY)
		else:
			a.text = "⚠ %s — Low (%d)" % [pname, c]
			a.add_theme_color_override("font_color", COL_LOW)
		a.add_theme_font_size_override("font_size", 13)
		alert_list.add_child(a)

	if db:
		for pid in db.get_all_product_ids():
			if _product_totals.get(pid, 0) <= 0:
				var p = db.get_product(pid)
				var n: String = p.product_name if p and "product_name" in p else pid.capitalize()
				var a := Label.new()
				a.text = "⚠ %s — OUT" % n
				a.add_theme_color_override("font_color", COL_EMPTY)
				a.add_theme_font_size_override("font_size", 13)
				alert_list.add_child(a)

func _add_row(parent: VBoxContainer, left: String, right: String, col: Color, bold: bool) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var lbl := Label.new()
	lbl.text = left
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.add_theme_font_size_override("font_size", 14 if bold else 13)
	lbl.add_theme_color_override("font_color", COL_TEXT)
	row.add_child(lbl)
	var rlbl := Label.new()
	rlbl.text = right
	rlbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	rlbl.add_theme_font_size_override("font_size", 14 if bold else 13)
	rlbl.add_theme_color_override("font_color", col)
	row.add_child(rlbl)
	parent.add_child(row)

func _add_bar(parent: VBoxContainer, val: int, mx: int, ratio: float) -> void:
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(0, 6)
	bar.max_value = mx
	bar.value = val
	bar.show_percentage = false
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.12, 0.12, 0.15)
	bg.corner_radius_top_left = 2
	bg.corner_radius_top_right = 2
	bg.corner_radius_bottom_left = 2
	bg.corner_radius_bottom_right = 2
	bar.add_theme_stylebox_override("background", bg)
	var fill := StyleBoxFlat.new()
	fill.bg_color = _ratio_color(ratio, val)
	fill.corner_radius_top_left = 2
	fill.corner_radius_top_right = 2
	fill.corner_radius_bottom_left = 2
	fill.corner_radius_bottom_right = 2
	bar.add_theme_stylebox_override("fill", fill)
	parent.add_child(bar)

func _add_sep(parent: VBoxContainer) -> void:
	var sep := HSeparator.new()
	sep.add_theme_constant_override("separation", 4)
	parent.add_child(sep)

func _ratio_color(ratio: float, val: int) -> Color:
	if val <= 0:
		return COL_EMPTY
	if ratio < LOW_RATIO:
		return COL_LOW
	return COL_OK

func _clear(container: VBoxContainer) -> void:
	for ch in container.get_children():
		ch.queue_free()
