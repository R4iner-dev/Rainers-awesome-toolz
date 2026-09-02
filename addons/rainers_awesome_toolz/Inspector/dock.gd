@tool
extends Control

const RELEASE_ASSET_NAME := "rainers_awesome_toolz.zip"
const PACKAGE_ROOT := "rainers_awesome_toolz"

var current_version := "0.0.0"
var repo := ""
var latest_version := ""
var download_url := ""
var expected_sha256 := ""

var temp_zip_path := "user://rainers_awesome_toolz_update.zip"
var temp_dir := "user://rainers_awesome_toolz_update"

@onready var status: Label = $VBoxContainer2/Status
@onready var version: Label = $VBoxContainer3/Version
@onready var latest: Label = $VBoxContainer3/LatestVersion
@onready var check_for_updates: Button = $VBoxContainer2/CheckForUpdates
@onready var update: Button = $VBoxContainer2/Update
@onready var http_request: HTTPRequest = $HTTPRequest
@onready var download_request: HTTPRequest = $DownloadRequest

func _ready() -> void:
	current_version = _get_plugin_version()

	repo = _get_repository()
	
	version.text = "Current Version: %s" % current_version

	http_request.request_completed.connect(_on_request_completed)
	download_request.request_completed.connect(_on_download_completed)

	update.visible = false

func _on_check_for_updates_pressed() -> void:
	status.text = "Checking for updates..."
	check_for_updates.disabled = true

	var url := "https://api.github.com/repos/%s/releases/latest" % repo

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

	latest_version = str(json.get("tag_name", ""))
	latest_version = latest_version.trim_prefix("v")

	latest.text = "Latest: %s" % latest_version

	if latest_version.is_empty():
		status.text = "Could not find release version."
		return

	var assets: Array = json.get("assets", [])

	download_url = ""
	expected_sha256 = ""

	for asset in assets:
		var asset_name := str(asset.get("name", ""))

		if asset_name == RELEASE_ASSET_NAME:
			download_url = str(asset.get("browser_download_url", ""))
			var digest: String = str(asset.get("digest", ""))
			if digest.begins_with("sha256:"):
				expected_sha256 = digest.trim_prefix("sha256:")
			break
	
	if _is_newer_version(latest_version, current_version):
		if download_url.is_empty():
			status.text = "Update available, but package is missing."
			update.visible = false
		else:
			status.text = "Update available!"
			update.text = "Update to %s" % latest_version
			update.visible = true
	else:
		status.text = "No updates available."
		update.visible = false

func _get_plugin_version() -> String:
	var config := ConfigFile.new()

	var error := config.load(
		"res://addons/%s/plugin.cfg" % PACKAGE_ROOT
	)

	if error != OK:
		return "unknown"

	return config.get_value("plugin", "version", "unknown")

func _get_repository() -> String:
	var config := ConfigFile.new()

	var error := config.load(
		"res://addons/%s/plugin.cfg" % PACKAGE_ROOT
	)

	if error != OK:
		return ""

	var url: String = config.get_value("plugin", "repository", "")
	if url.begins_with("https://github.com/"):
		return url.trim_prefix("https://github.com/")
	return url

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

func _on_update_pressed() -> void:
	if download_url.is_empty():
		status.text = "No update package found."
		return

	status.text = "Downloading update..."

	update.disabled = true
	check_for_updates.disabled = true

	download_request.download_file = temp_zip_path

	var error := download_request.request(download_url)

	if error != OK:
		status.text = "Could not start download."
		update.disabled = false
		check_for_updates.disabled = false

func _on_download_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS:
		status.text = "Download failed."
		_cleanup_temp_zip()
		_reset_buttons()
		return

	if response_code != 200:
		status.text = "Download failed: HTTP %d" % response_code
		_cleanup_temp_zip()
		_reset_buttons()
		return

	if not expected_sha256.is_empty():
		status.text = "Verifying download..."
		var actual_sha256 := _sha256_of_file(temp_zip_path)
		if actual_sha256 != expected_sha256:
			status.text = "SHA-256 mismatch — download may be corrupt."
			_cleanup_temp_zip()
			_reset_buttons()
			return

	status.text = "Download verified."

	_install_update()

func _install_update() -> void:
	status.text = "Validating package..."

	var zip := ZIPReader.new()

	var error := zip.open(temp_zip_path)

	if error != OK:
		status.text = "Could not open update package."
		_cleanup_temp_zip()
		_reset_buttons()
		return

	var files := zip.get_files()

	var has_addon_root := false

	for file_path in files:
		if not _safe_zip_path(file_path):
			zip.close()
			status.text = "Update package contains an unsafe path."
			_cleanup_temp_zip()
			_reset_buttons()
			return

		if file_path.begins_with("rainers_awesome_toolz/") or file_path == "rainers_awesome_toolz":
			has_addon_root = true

	if not has_addon_root:
		zip.close()
		status.text = "Update package has an invalid structure."
		_cleanup_temp_zip()
		_reset_buttons()
		return

	status.text = "Extracting update..."

	_remove_directory(temp_dir)

	DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(temp_dir)
	)

	for file_path in files:
		if file_path.ends_with("/"):
			continue

		var destination := temp_dir.path_join(file_path)

		var destination_dir := destination.get_base_dir()

		DirAccess.make_dir_recursive_absolute(
			ProjectSettings.globalize_path(destination_dir)
		)

		var data := zip.read_file(file_path)

		var file := FileAccess.open(destination, FileAccess.WRITE)

		if file == null:
			zip.close()
			status.text = "Could not write update files."
			_cleanup_temp_zip()
			_remove_directory(temp_dir)
			_reset_buttons()
			return

		file.store_buffer(data)

	zip.close()
	_cleanup_temp_zip()

	status.text = "Package extracted."

	_replace_addon()

func _replace_addon() -> void:
	var addon_path := "res://addons/rainers_awesome_toolz"
	var backup_path := "res://addons/rainers_awesome_toolz_backup"

	var addon_absolute := ProjectSettings.globalize_path(addon_path)
	var backup_absolute := ProjectSettings.globalize_path(backup_path)
	var new_addon_absolute := ProjectSettings.globalize_path(
		temp_dir.path_join(PACKAGE_ROOT)
	)

	if DirAccess.dir_exists_absolute(backup_absolute):
		_remove_directory(backup_path)

	var error := DirAccess.rename_absolute(addon_absolute, backup_absolute)

	if error != OK:
		status.text = "Could not back up current addon."
		_remove_directory(temp_dir)
		_reset_buttons()
		return

	error = DirAccess.rename_absolute(new_addon_absolute, addon_absolute)

	if error != OK:
		DirAccess.rename_absolute(backup_absolute, addon_absolute)
		status.text = "Could not install new addon."
		_remove_directory(temp_dir)
		_reset_buttons()
		return

	# Keeps the backup in place until the next successful update 
	_remove_directory(temp_dir)

	status.text = "Update installed! Restart Godot to finish."
	update.visible = false
	_reset_buttons()

func _remove_directory(path: String) -> void:
	var absolute_path := ProjectSettings.globalize_path(path)

	if not DirAccess.dir_exists_absolute(absolute_path):
		return

	_remove_directory_contents(absolute_path)

	DirAccess.remove_absolute(absolute_path)

func _remove_directory_contents(path: String) -> void:
	var dir := DirAccess.open(path)

	if dir == null:
		return

	dir.list_dir_begin()

	while true:
		var file_name := dir.get_next()

		if file_name.is_empty():
			break

		if file_name == "." or file_name == "..":
			continue

		var full_path := path.path_join(file_name)

		if dir.current_is_dir():
			_remove_directory_contents(full_path)
			DirAccess.remove_absolute(full_path)
		else:
			DirAccess.remove_absolute(full_path)

	dir.list_dir_end()

func _safe_zip_path(path: String) -> bool:
	if path.begins_with("/"):
		return false

	var parts := path.split("/")

	for part in parts:
		if part == "..":
			return false

	return true

func _sha256_of_file(path: String) -> String:
	var ctx := HashingContext.new()
	if ctx.start(HashingContext.HASH_SHA256) != OK:
		return ""
	var data := FileAccess.get_file_as_bytes(path)
	if data.is_empty():
		return ""
	ctx.update(data)
	return ctx.finish().hex_encode()

func _cleanup_temp_zip() -> void:
	if FileAccess.file_exists(temp_zip_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(temp_zip_path))

func _reset_buttons() -> void:
	update.disabled = false
	check_for_updates.disabled = false