## Renders one generic statistics section as tiles, an icon grid, or ranked bars.
class_name StatisticsSection
extends VBoxContainer


@export var stat_tile_scene: PackedScene
@export var icon_cell_scene: PackedScene
@export var bar_row_scene: PackedScene
## Share of the shared stagger delay used between this section's entries.
@export_range(0.0, 2.0, 0.05) var entry_stagger_ratio := 0.5
## Entries past this index appear together so long sections do not drag.
@export_range(0, 40, 1) var max_staggered_entries := 10

@onready var icon_rect: TextureRect = %Icon
@onready var title_label: Label = %Title
@onready var subtitle_label: Label = %Subtitle
@onready var tiles: GridContainer = %Tiles
@onready var icon_grid: HFlowContainer = %IconGrid
@onready var bars: VBoxContainer = %Bars

var _content: Container


func configure(section: StatisticsSectionViewData) -> void:
	icon_rect.texture = section.icon
	icon_rect.visible = section.icon != null
	title_label.text = section.title
	subtitle_label.text = section.subtitle
	subtitle_label.visible = not section.subtitle.is_empty()
	var entry_scene := stat_tile_scene
	_content = tiles
	match section.layout:
		StatisticsSectionViewData.Layout.ICON_GRID:
			entry_scene = icon_cell_scene
			_content = icon_grid
		StatisticsSectionViewData.Layout.BARS:
			entry_scene = bar_row_scene
			_content = bars
	for container: Container in [tiles, icon_grid, bars]:
		for child in container.get_children():
			child.free()
		container.visible = container == _content
	for entry in section.entries:
		if entry == null:
			continue
		var control := entry_scene.instantiate() as StatisticsEntryControl
		_content.add_child(control)
		control.configure(entry)


## Fades the section in after `delay` and reveals its entries one after another.
func play_intro(delay: float) -> void:
	UiMotion.fade_in(self, delay)
	if _content == null:
		return
	var step := UiMotion.config().stagger_delay * entry_stagger_ratio
	for index in _content.get_child_count():
		var entry := _content.get_child(index) as StatisticsEntryControl
		if entry != null:
			entry.play_intro(delay + step * mini(index, max_staggered_entries))


func entry_count() -> int:
	return _content.get_child_count() if _content != null else 0


func entry_control(index: int) -> StatisticsEntryControl:
	if _content == null or index < 0 or index >= _content.get_child_count():
		return null
	return _content.get_child(index) as StatisticsEntryControl
