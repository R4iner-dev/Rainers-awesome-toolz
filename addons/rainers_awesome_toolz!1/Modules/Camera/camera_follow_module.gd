## Handles camera follow functionality for both first-person and third-person views. NOTE: This works only on 3d games for now.

extends Node
class_name CameraFollowModule

enum CameraView {
    FIRST_PERSON,
    THIRD_PERSON
}

@export var enabled: bool = true
@export var camera_view: CameraView = CameraView.FIRST_PERSON
@export var mouse_mode = Input.MOUSE_MODE_CAPTURED
@export var mouse_sensitivity: float = 0.002
@export_category("First Person Camera")
@export var controller: CharacterBody3D
@export var camera: Camera3D
@export var first_person_position := Vector3(0.0, 1.6, 0.0)
@export_category("Third Person Camera")
@export var spring_arm: SpringArm3D
@export var camera_pivot: Node3D
@export var third_person_distance: float = 4.0
@export var third_person_height: float = 1.0

var camera_rot_y: float = 0.0
var camera_rot_x: float = 0.0
var current_view: CameraView

func _ready() -> void:
    if not enabled:
        return

    Input.set_mouse_mode(mouse_mode)

    if controller:
        camera_rot_y = controller.rotation.y

    if camera_pivot:
        camera_rot_x = camera_pivot.rotation.x

    switch_camera_view(camera_view)

func _unhandled_input(event: InputEvent) -> void:
    if not enabled:
        return
    if not controller:
        return

    if event is InputEventMouseMotion:
        if Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED:
            return

        camera_rot_y -= event.relative.x * mouse_sensitivity
        camera_rot_x -= event.relative.y * mouse_sensitivity

        camera_rot_x = clamp(camera_rot_x, deg_to_rad(-90.0), deg_to_rad(90.0))
        update_camera_rotation()

func update_camera_rotation() -> void:
    if controller:
        controller.rotation.y = camera_rot_y
    
    if camera_pivot:
        camera_pivot.rotation.x = camera_rot_x


func switch_camera_view(view: CameraView) -> void:
    camera_view = view

    match camera_view:
        CameraView.FIRST_PERSON:
            set_first_person_view()
        CameraView.THIRD_PERSON:
            set_third_person_view()

func set_first_person_view() -> void:
    if not camera_pivot or not spring_arm:
        return

    camera_pivot.position = first_person_position
    spring_arm.spring_length = 0.0
    current_view = CameraView.FIRST_PERSON

func set_third_person_view() -> void:
    if not camera_pivot or not spring_arm:
        return

    camera_pivot.position = Vector3(
        0.0,
        third_person_height,
        0.0
    )

    spring_arm.spring_length = third_person_distance
    current_view = CameraView.THIRD_PERSON
