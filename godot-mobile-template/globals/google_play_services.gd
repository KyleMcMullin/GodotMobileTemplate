extends Node

signal google_play_authenticated()

# Signal out of here when you load saves to places where data is used
#signal saves_loaded

const ACHIEVEMENT_IDS: Dictionary = {} # example:  PlatformServices.ACHIEVEMENT.100_PERCENT: "ACHIEVEMENT_ID_FROM_GOOGLE_PLAY_CONSOLE"
const LEADERBOARD_IDS: Dictionary = {} #example: PlatformServices.LEADERBOARD.FASTEST_LEVEL: LEADERBOARD_ID_FROM_GOOGLE_PLAY_CONSOLE"

const cloud_paths: Dictionary = {} # Example: LEVELS_COMPLETED: "completed_levels"
# highly recommended to constantize/enum the keys here however it makes sense for your game's save data

@onready var play_games_sign_in_client: PlayGamesSignInClient = %PlayGamesSignInClient
@onready var play_games_achievements_client: PlayGamesAchievementsClient = %PlayGamesAchievementsClient
@onready var play_games_leaderboards_client: PlayGamesLeaderboardsClient = %PlayGamesLeaderboardsClient
@onready var play_games_snapshots_client: PlayGamesSnapshotsClient = %PlayGamesSnapshotsClient

var config: ConfigFile = ConfigFile.new()
const config_path: String = "user://user_config.cfg"

var is_user_authenticated: bool = false

var saved_snapshot_ids: Dictionary = {}

func _enter_tree() -> void:
	if not PlatformServices.is_android():
		queue_free()
	
func _ready() -> void:
	if not PlatformServices.is_android():
		return
	google_play_authenticated.connect(PlatformServices.signed_in_success)
	## Connect the saves_loaded signal to wherever uses the data you need it to
	#saves_loaded.connect()
	if _initialize_if_allowed():
		play_games_sign_in_client.is_authenticated()

func _initialize_if_allowed() -> bool:
	if AdManager.is_child or not AdManager.age_verified:
		return false
	if not GodotPlayGameServices.android_plugin:
		GodotPlayGameServices.initialize()
	return GodotPlayGameServices.android_plugin != null

func _on_user_authenticated(is_authenticated: bool) -> void:
	is_user_authenticated = is_authenticated
	if is_authenticated:
		google_play_authenticated.emit()
		# load the snapshots when they are signed in
		play_games_snapshots_client.load_snapshots(true)

func sign_in() -> void:
	if _initialize_if_allowed():
		play_games_sign_in_client.sign_in()
	
func show_achievements() -> void:
	play_games_achievements_client.show_achievements()
	
func show_leaderboards() -> void:
	play_games_leaderboards_client.show_all_leaderboards()
	
func unlock_achievement(achievement: PlatformServices.ACHIEVEMENT) -> void:
	play_games_achievements_client.unlock_achievement(ACHIEVEMENT_IDS[achievement])
	
func increment_achievement(achievement: PlatformServices.ACHIEVEMENT, value: int = 1) -> void:
	play_games_achievements_client.increment_achievement(ACHIEVEMENT_IDS[achievement], value)
	

# This saves the config file from the snapshot, then reloads all the important areas that use it
func _update_config_from_snapshot(snapshot: PlayGamesSnapshot) -> void:
	# Preferences may roam; consent, age and purchase entitlements stay local.
	var restored: ConfigFile = ConfigFile.new()
	if restored.parse(snapshot.content.get_string_from_utf8()) != OK:
		return
	config.load(config_path)
	for key: String in restored.get_section_keys("audio") if restored.has_section("audio") else PackedStringArray():
		config.set_value("audio", key, restored.get_value("audio", key))
	config.save(config_path)
	AudioManager._load_config_file()
	
	
func cloud_save_config() -> void:
	if !is_user_authenticated or AdManager.is_child: return
	var _err: Error = config.load(config_path)
	var preferences: ConfigFile = ConfigFile.new()
	if config.has_section("audio"):
		for key: String in config.get_section_keys("audio"):
			preferences.set_value("audio", key, config.get_value("audio", key))
	var content: PackedByteArray = preferences.encode_to_text().to_utf8_buffer()
	play_games_snapshots_client.save_game("user_config", "user config file", content)
	

func add_score_to_leaderboard(leaderboard: PlatformServices.LEADERBOARD, number: int) -> void:
	play_games_leaderboards_client.submit_score(LEADERBOARD_IDS[leaderboard], number)
	

func _snapshots_loaded(snapshots: Array[PlayGamesSnapshotMetadata]) -> void:
	for snapshot: PlayGamesSnapshotMetadata in snapshots:
		if snapshot.unique_name == "user_config" or snapshot.unique_name in cloud_paths.values():
			saved_snapshot_ids.get_or_add(snapshot.snapshot_id, true)
			play_games_snapshots_client.load_game(snapshot.unique_name)
	
func _load_config_save() -> void:
	play_games_snapshots_client.load_game("user_config")
	
func _game_loaded(snapshot: PlayGamesSnapshot) -> void:
	if snapshot == null: return
	if "dataType" in snapshot.metadata.unique_name:
		pass
		# dispatch this to wherever you need your data to go
	elif "user_config" == snapshot.metadata.unique_name:
		_update_config_from_snapshot(snapshot)

func _conflict_emitted(_conflict: PlayGamesSnapshotConflict) -> void:
	#play_games_snapshots_client.resolve
	print("conflict emitted")


#func cloud_save_data(path: Type, data: Type) -> void:
	## Convert your data to a PackedByteArray, you can use FileAccess.get_file_as_bytes for this
	#var raw_data: PackedByteArray
	#play_games_snapshots_client.save_game(cloud_paths[PATH], "data.Type " + str(data) + " save data", raw_data)
	
func delete_save_data() -> void:
	if not is_user_authenticated: return
	for key: String in saved_snapshot_ids.keys():
		play_games_snapshots_client.delete_snapshot(key)
	saved_snapshot_ids.clear()
