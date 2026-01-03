extends Node

# 备忘录数据 (简单的字符串数组)
var memos: Array[String] = [
	"记得喝水！",
	"做完这个功能就去睡觉。",
	"明天要交作业。"
]

# 模拟新闻数据 (真实开发可以用 HTTPRequest 获取 API)
var news_list: Array[Dictionary] = [
	{"title": "Godot 4.4 发布预览版！", "url": "https://godotengine.org"},
	{"title": "今天天气不错，适合敲代码。", "url": "https://weather.com"},
	{"title": "鸭子模拟器登顶 Steam 销量榜 (误)", "url": "https://store.steampowered.com"}
]

# 添加备忘录
func add_memo(text: String):
	if text.strip_edges() != "":
		memos.append(text)

# 获取随机内容
func get_random_content() -> Dictionary:
	var type = randi() % 3 # 0: 备忘录, 1: 时间, 2: 新闻
	
	var result = {"type": "", "text": "", "data": null}
	
	match type:
		0: # 备忘录
			result.type = "memo"
			if memos.is_empty():
				result.text = "备忘录是空的..."
			else:
				result.text = memos.pick_random()
		1: # 时间
			result.type = "time"
			var time = Time.get_time_dict_from_system()
			result.text = "现在是 %02d:%02d" % [time.hour, time.minute]
		2: # 新闻
			result.type = "news"
			var news = news_list.pick_random()
			result.text = "NEWS: " + news.title
			result.data = news.url
			
	return result


# --- 新增 ---
# 标记鼠标是否正在悬停在某个可交互对象（如鸭子）上
var is_mouse_busy: bool = false