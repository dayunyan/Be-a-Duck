extends PanelContainer

@onready var text_edit = $VBoxContainer/TextEdit
@onready var close_btn = $VBoxContainer/TopBar/CloseButton
@onready var save_btn = $VBoxContainer/SaveButton

func _ready():
	# 连接信号
	close_btn.pressed.connect(_on_close_pressed)
	save_btn.pressed.connect(_on_save_pressed)
	
	# 初始隐藏
	visible = false

# 打开时刷新内容
func open():
	visible = true
	# 将 GameData 里的备忘录数组转换成字符串显示
	# 这里简单处理：一行一条
	var content = ""
	for memo in GameData.memos:
		content += memo + "\n"
	text_edit.text = content

func _on_close_pressed():
	visible = false

func _on_save_pressed():
	# 保存逻辑：清空原有数组，把编辑框的内容按行分割存回去
	GameData.memos.clear()
	var lines = text_edit.text.split("\n", false) # false 表示忽略空行
	for line in lines:
		GameData.add_memo(line)
	
	visible = false
	print("备忘录已保存")