@tool
extends EditorPlugin

var dock: EditorDock

func _enter_tree() -> void:
    var dock_scene := preload("res://addons/rainers_awesome_toolz!1/Inspector/dock.tscn")
    var dock_control := dock_scene.instantiate()

    dock = EditorDock.new()
    dock.add_child(dock_control)

    dock.title = "Toolz"
    dock.default_slot = dock.DOCK_SLOT_LEFT_UR

    dock.available_layouts = (
        EditorDock.DOCK_LAYOUT_VERTICAL
        | EditorDock.DOCK_LAYOUT_FLOATING
        | EditorDock.DOCK_LAYOUT_HORIZONTAL
    )

    add_dock(dock)


func _exit_tree() -> void:
    remove_dock(dock)
    dock.queue_free()
