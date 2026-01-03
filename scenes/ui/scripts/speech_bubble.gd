extends PanelContainer

signal bubble_clicked(type, data)

@onready var label = $MarginContainer/Label
@onready var button = $Button

var content_type: String = ""
var content_data = null

func setup(text: String, type: String, data = null):
	# 1. 先填充内容
	label.text = text
	content_type = type
	content_data = data
	
	# 2. 基础设置：设置最小宽度，保证能换行
	label.custom_minimum_size.x = 150
	
	# --- 关键修改开始 ---
	
	# 第一步：先关闭省略模式，重置高度限制，让 Label 自由生长
	label.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	label.max_lines_visible = -1 # -1 表示显示所有行
	label.custom_minimum_size.y = 0 
	
	# 第二步：等待一帧，让 Godot 计算出文本在当前宽度下到底有几行
	await get_tree().process_frame
	
	# 3. 检查是否需要截断
	var line_count = label.get_line_count()
	
	if line_count > 3:
		# 开启省略号
		label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		label.max_lines_visible = 3
		
		# --- 修复核心：更精确的高度计算 ---
		# 获取单行高度
		var line_h = label.get_line_height()
		
		# 理论高度是 3 * line_h。
		# 但为了防止底部留白太多，我们可以减去一点点 padding，或者不做减法，
		# 关键是下面的重置容器尺寸。
		# 这里我建议手动微调：乘以 3 之后，减去 2~4 像素通常看起来更紧凑
		label.custom_minimum_size.y = (line_h * 3.5)
		
		# --- 修复核心：强制 PanelContainer 缩小 ---
		# 之前 Panel 被撑大到了 line_count 行，现在我们需要它缩回 3 行
		# 将 size 设为 0，Godot 会自动将其扩展到子节点的最小尺寸（即刚才设的 custom_minimum_size.y）
		self.size = Vector2.ZERO 
	
	# 5秒后自动消失
	await get_tree().create_timer(5.0).timeout
	queue_free()


func _on_mouse_entered():
	GameData.is_mouse_busy = true

func _on_mouse_exited():
	GameData.is_mouse_busy = false

func _exit_tree():
    # 简单的防卡死机制
	if GameData.is_mouse_busy:
		GameData.is_mouse_busy = false

func _ready():
	button.pressed.connect(_on_clicked)
	# 出现动画
	scale = Vector2.ZERO
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK)
	
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)

func _on_clicked():
	bubble_clicked.emit(content_type, content_data)
	# 点击后也可以选择直接销毁
	queue_free()
