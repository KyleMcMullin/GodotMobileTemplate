extends Node

signal signed_in

enum ACHIEVEMENT {} # example: 100_PERCENT
enum LEADERBOARD {} # example: FASTEST_LEVEL

enum PLATFORM {
	ANDROID,
	IOS,
	OTHER
}

enum PURCHASE {} # example: AD_FREE

const PURCHASE_STRINGS: Dictionary = {} # example: PURCHASE.AD_FREE: "ad_free"

const ios_platforms: Array = ["ios"] # maybe in the future add "web_ios" "macos" "web_macos"
const android_platforms: Array = ["android"] #consider adding "web_android"
# if you are going to support any other platforms, add them here

var config: ConfigFile = ConfigFile.new()
const config_path: String = "user://user_config.cfg"

var platform: PLATFORM = PLATFORM.OTHER
var is_user_authenticated: bool = false

func _enter_tree() -> void:
	for test_platform: String in ios_platforms:
		if OS.has_feature(test_platform):
			platform = PLATFORM.IOS
			return
	for test_platform: String in android_platforms:
		if OS.has_feature(test_platform):
			platform = PLATFORM.ANDROID
			return

#func _ready() -> void:
	#_load_config_file()
	
## Load/Save any achievement related data from the config
## IE. If you have an achievement of DO X things Y times, you would save how many times they did it
## Load that value on startup, and then when they do it again + 1 to the value, save it, check if they got the achievement
	
#func _save_config_file() -> void:
	#var _err: Error = config.load(config_path)
	#config.set_value("achievements", "EXAMPLE", true)
	#config.save(config_path)
	#cloud_save_config()
		

#func _load_config_file() -> bool:
	#var err: Error = config.load(config_path)
	#if err != OK:
		#return false
	#return true
		
## Example function, this is where you would check conditions for an achievement in the game
## If they've earned it, then call unlock achievement
#func test_achievement() -> void:
	#const example_achievement_100_percent = false
	#if example_achievement_100_percent:
		#unlock_achievement(ACHIEVEMENT.100_PERCENT)
	# OPTIONAL: this part is to save the data so you don't have to recalculate this everytime. Ie. Save completion as 85%
	# _save_config_file()

	
func unlock_achievement(achievement: ACHIEVEMENT) -> void:
	if platform == PLATFORM.ANDROID:
		GooglePlayServices.unlock_achievement(achievement)
	elif platform == PLATFORM.IOS:
		pass

func show_achievements() -> void:
	if platform == PLATFORM.ANDROID:
		GooglePlayServices.show_achievements()
		
func add_score_to_leaderboard(number: int) -> void:
	if platform == PLATFORM.ANDROID:
		GooglePlayServices.add_score_to_leaderboard(number)
		
func show_leaderboard() -> void:
	if platform == PLATFORM.ANDROID:
		GooglePlayServices.show_leaderboard()
		
func increment_achievement(achievement: ACHIEVEMENT, value: int = 1) -> void:
	if platform == PLATFORM.ANDROID:
		GooglePlayServices.increment_achievement(achievement, value)
		
	
		
func cloud_save_config() -> void:
	if platform == PLATFORM.ANDROID:
		GooglePlayServices.cloud_save_config()
		
func delete_save_data() -> void:
	if platform == PLATFORM.ANDROID:
		GooglePlayServices.delete_save_data()
		
func signed_in_success() -> void:
	signed_in.emit()
	if platform == PLATFORM.ANDROID:
		is_user_authenticated = GooglePlayServices.is_user_authenticated
	else:
		is_user_authenticated = false
	
func purchase(item: PURCHASE) -> void:
	if platform == PLATFORM.ANDROID:
		GooglePlayBilling.purchase(PURCHASE_STRINGS[item])

func sign_in() -> void:
	if platform == PLATFORM.ANDROID:
		GooglePlayServices.sign_in()
		
func is_android() -> bool:
	return platform == PLATFORM.ANDROID
	
func is_ios() -> bool:
	return platform == PLATFORM.IOS
