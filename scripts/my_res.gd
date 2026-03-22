extends Resource
class_name MyRes

const LANDSCAPE_WIDTH := 1920
const PORTRAIT_WIDTH := 1080
const WORKSHOP_CACHE_VERSION := 1
const CUSTOM_FOLDER_STORE_VERSION := 1
const CUSTOM_FOLDER_ITEM_TYPE := "custom_folder"

const MY_WORKSHOP_ROOT := "D:/Steam/steamapps/workshop/content/431960"
const MY_LOCAL_PROJECTS_ROOT := "D:/Steam/steamapps/common/wallpaper_engine/projects/myprojects"

var WORKSHOP_ROOT := ""
var LOCAL_PROJECTS_ROOT := ""


# python相关路径
const PYTHON_EXE_PATH := "D:/AGodotProjects/test-3/py/.venv/Scripts/python.exe"
const CONVERTER_SCRIPT_PATH := "D:/AGodotProjects/test-3/py/converter.py"
const CONVERTER_PROGRESS_PATH := "D:/AGodotProjects/test-3/py/convert_progress.txt"

# 缓存和配置文件路径
const GIF_CACHE_DIR_PATH := "user://gif_cache/"
const WORKSHOP_CACHE_PATH := "user://workshop_video_cache.json"
const CUSTOM_FOLDER_STORE_PATH := "user://custom_folders.json"
const CONFIG_PATH := "user://config.json"

#deprecated
const SUBSCRIPTIONS_VDF_PATH := "D:/Steam/userdata/213406194/ugc/431960_subscriptions.vdf"