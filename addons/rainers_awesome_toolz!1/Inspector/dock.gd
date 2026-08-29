@tool
extends Control

const REPO := "R4iner-dev/Rainers-awesome-toolz"
const CURRENT_VERSION := "1.0.0"

@onready var status: Label = $VBoxContainer/Status
@onready var current_version: Label = $VBoxContainer2/CurrentVersion
@onready var check_for_updates: Button = $VBoxContainer/CheckForUpdates
@onready var http_request: HTTPRequest = $HTTPRequest

func _ready() -> void:
	current_version.text = "Current Version: %s" % CURRENT_VERSION
	http_request.request_completed.connect(_on_request_completed)

func _on_check_for_updates_pressed() -> void:
	status.text = "Checking for updates..."
	check_for_updates.disabled = true

	var url := "https://api.github.com/repos/%s/releases/latest" % REPO

	var headers := PackedStringArray([
		"Accept: application/vnd.github+json",
		"X-GitHub-Api-Version: 2026-03-10"
	])

	var error := http_request.request(url, headers)

	if error != OK:
		status.text = "Could not start update check."
		check_for_updates.disabled = false


func _on_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	check_for_updates.disabled = false

	if result != HTTPRequest.RESULT_SUCCESS:
		status.text = "Could not connect to GitHub."
		return

	if response_code != 200:
		status.text = "GitHub returned error %d." % response_code
		return

	var json := JSON.parse_string(body.get_string_from_utf8())

	if json == null:
		status.text = "GitHub returned invalid data."
		return

	var latest_version: String = json.get("tag_name", "")

	if latest_version.is_empty():
		status.text = "Could not find release version."
		return

	latest_version = latest_version.trim_prefix("v")

	status.text = "Latest: %s" % latest_version

	if _is_newer_version(latest_version, CURRENT_VERSION):
		status.text = "Update available!"
	else:
		status.text = "No updates available."

func _is_newer_version(latest: String, current: String) -> bool:
	var latest_parts := _parse_version(latest)
	var current_parts := _parse_version(current)

	for i in range(3):
		if latest_parts[i] > current_parts[i]:
			return true

		if latest_parts[i] < current_parts[i]:
			return false

	return false

func _parse_version(version: String) -> Array[int]:
	version = version.trim_prefix("v")

	var parts := version.split(".")

	var result: Array[int] = [0, 0, 0]

	for i in range(min(parts.size(), 3)):
		result[i] = int(parts[i])

	return result