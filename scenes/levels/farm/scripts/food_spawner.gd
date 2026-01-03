extends Node2D

var food_scene: PackedScene = preload("res://entities/items/food.tscn")

# 投喂半径
var spawn_radius: float = 60.0

# 引用 ItemsLayer，确保食物生成在这个节点下
# 注意：你需要根据上一步的操作，正确引用 MainGame 里的 ItemsLayer
# 如果 FoodSpawner 是 MainGame 的直接子节点，路径通常是 "../ItemsLayer"
@onready var items_layer = get_node("../ItemsLayer") 
@onready var spawn_timer: Timer = $SpawnTimer

func _ready():
	spawn_timer.timeout.connect(_on_spawn_timer_timeout)

func _unhandled_input(event):
	# 额外检查：如果鼠标正悬停在鸭子上，也不要处理投食
	if GameData.is_mouse_busy:
		spawn_timer.stop() # 如果按着拖动时滑到了鸭子上，停止生成
		return

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				spawn_timer.start()
				spawn_food_batch()
			else:
				spawn_timer.stop()

func _on_spawn_timer_timeout():
	spawn_food_batch()

# 批量生成逻辑
func spawn_food_batch():
	# 每次触发生成 2 到 4 个食物
	var count = randi_range(2, 4)
	
	for i in range(count):
		spawn_single_food()

func spawn_single_food():
	var mouse_pos = get_global_mouse_position()
	
	# 1. 计算随机位置
	var angle = randf() * TAU
	# 使用 sqrt 保证圆内分布均匀，否则圆心会很密集
	var radius = sqrt(randf()) * spawn_radius 
	var random_offset = Vector2(cos(angle), sin(angle)) * radius
	var target_pos = mouse_pos + random_offset
	
	# 2. 核心优化：位置合法性检测
	if not is_valid_position(target_pos):
		return # 如果位置在墙里或水里，这一粒食物就不生成了
		
	# 3. 实例化
	var new_food = food_scene.instantiate()
	items_layer.add_child(new_food)
	
	# 4. 动画效果：从天而降
	# 先设置到空中位置 (y轴向上偏移)
	var start_pos = target_pos + Vector2(0, -30)
	new_food.position = start_pos
	# 初始设为透明或缩小，增加出现感
	new_food.scale = Vector2.ZERO 
	
	# 创建 Tween 动画
	var tween = create_tween()
	tween.set_parallel(true) # 让下面的动画同时发生
	
	# 跌落动画 (弹跳效果)
	tween.tween_property(new_food, "position", target_pos, 0.4).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	# 缩放动画 (从0变到1)
	tween.tween_property(new_food, "scale", Vector2.ONE, 0.3)
	
	# 稍微加一点随机旋转
	new_food.rotation = randf_range(-0.5, 0.5)

# 物理检测函数
func is_valid_position(pos: Vector2) -> bool:
	# 获取物理空间状态
	var space_state = get_world_2d().direct_space_state
	
	# 创建一个点查询参数
	var query = PhysicsPointQueryParameters2D.new()
	query.position = pos
	
	# 设置碰撞掩码 (Collision Mask)
	# 我们之前设置过：
	# Layer 1 = World (墙/水)
	# Layer 2 = Duck
	# 这里的 1 代表二进制的 0000...0001，即只检测 Layer 1
	query.collision_mask = 1 
	
	# 执行查询
	var result = space_state.intersect_point(query)
	
	# 如果结果数组不为空，说明那个点撞到了 Layer 1 的东西（水或墙）
	if result.size() > 0:
		return false # 位置无效
		
	# 还需要检查是否超出屏幕边缘 (防止生成在屏幕外)
	var screen_rect = get_viewport_rect()
	# 留 32 像素的边距
	if not screen_rect.grow(-32).has_point(pos):
		return false
		
	return true