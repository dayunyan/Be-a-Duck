extends CharacterBody2D

# GDScript 的变量导出写法
@export var move_speed: float = 50.0

# 需求系统属性
@export var max_thirst: float = 100.0
@export var thirst_decay_rate: float = 5.0
var current_thirst: float

@export var max_hunger: float = 100.0
@export var hunger_decay_rate: float = 3.0
var current_hunger: float

# 定义状态枚举 (GDScript 的枚举很简单)
enum DuckState {
	IDLE,
	WANDER,
	SEEK_WATER,
	SEEK_FOOD
}

var current_state: DuckState = DuckState.IDLE
var move_direction: Vector2 = Vector2.ZERO
var target_water_source: Node2D = null
var target_food: Node2D = null

# 预加载气泡场景
var bubble_scene = preload("res://scenes/ui/speech_bubble.tscn")
# 说话计时器 (可以在 _ready 里通过代码创建，不用拖节点)
var talk_timer: Timer

# 节点引用 (onready 关键字：在 _ready 时自动获取，非常方便)
@onready var anim_sprite: AnimatedSprite2D = $AnimSprite
@onready var decision_timer: Timer = $DecisionTimer
@onready var thirst_bar: ProgressBar = $StatusUI/ThirstBar
@onready var hunger_bar: ProgressBar = $StatusUI/HungerBar

# 获取 Shader 材质引用 (注意：材质在 AnimSprite 上)
@onready var sprite_mat: ShaderMaterial = anim_sprite.material
@onready var status_ui: Control = $StatusUI

# 新增导航代理引用
@onready var nav_agent: NavigationAgent2D = $NavigationAgent2D

# 获取屏幕大小
var screen_rect: Rect2

func _ready():
	# --- 新增：资源唯一化 ---
	# 检查是否存在材质，如果存在，复制一份副本给自己
	# 这样修改 is_enabled 就只会影响当前这只鸭子
	if anim_sprite.material:
		anim_sprite.material = anim_sprite.material.duplicate()
	# 重新获取材质引用
	sprite_mat = anim_sprite.material
	# -----------------------

	# 初始化数值
	current_thirst = max_thirst
	current_hunger = max_hunger
	
	# 初始化 UI 最大值
	thirst_bar.max_value = max_thirst
	hunger_bar.max_value = max_hunger
	
	# 连接信号 (Python 风格的 connect)
	decision_timer.timeout.connect(_on_decision_timer_timeout)
	
	pick_new_state()
	update_animation()

	# 连接鼠标信号 (CharacterBody2D 自带的信号)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	
	# 确保初始状态正确
	status_ui.visible = false
	if sprite_mat:
		sprite_mat.set_shader_parameter("is_enabled", false)

	# 设置说话计时器
	talk_timer = Timer.new()
	talk_timer.one_shot = true
	add_child(talk_timer)
	talk_timer.timeout.connect(_on_talk_timer_timeout)
	
	# 启动随机说话倒计时 (比如 10 到 30 秒说一次)
	reset_talk_timer()

func _on_mouse_entered():
	status_ui.visible = true
	if sprite_mat:
		sprite_mat.set_shader_parameter("is_enabled", true)
	
	# 告诉全局：鼠标现在很忙，别撒粮
	GameData.is_mouse_busy = true

func _on_mouse_exited():
	status_ui.visible = false
	if sprite_mat:
		sprite_mat.set_shader_parameter("is_enabled", false)
	
	# 告诉全局：鼠标空闲了（离开这只鸭子了）
	GameData.is_mouse_busy = false

func _physics_process(delta):
	screen_rect = get_viewport_rect()
	
	# 数值衰减
	current_thirst -= thirst_decay_rate * delta
	current_hunger -= hunger_decay_rate * delta
	
	# 更新 UI
	thirst_bar.value = current_thirst
	hunger_bar.value = current_hunger
	
	# 检测口渴
	if current_thirst <= 30.0 and current_state != DuckState.SEEK_WATER:
		start_seeking_water()
	elif current_hunger <= 40.0 and current_state != DuckState.SEEK_FOOD and current_state != DuckState.SEEK_WATER:
		start_seeking_food()
	
	# 状态机逻辑
	match current_state:
		DuckState.IDLE:
			velocity = Vector2.ZERO
			
		DuckState.WANDER:
			# 游荡依然可以用直线移动，或者也改为寻路(随机取一个点)
			# 这里为了简单，游荡保持直线碰撞反弹，因为游荡不需要绕过障碍物去特定点
			velocity = move_direction * move_speed
			move_and_slide()
			check_bounds()
			
		DuckState.SEEK_WATER, DuckState.SEEK_FOOD:
			# 寻路状态使用特定函数
			handle_navigation_movement(delta)
			
	update_animation()

func check_bounds():
	var pos = position
	var hit_wall = false
	var margin = 16.0
	
	if pos.x < margin:
		pos.x = margin
		move_direction.x *= -1
		hit_wall = true
	elif pos.x > screen_rect.size.x - margin:
		pos.x = screen_rect.size.x - margin
		move_direction.x *= -1
		hit_wall = true
		
	if pos.y < margin:
		pos.y = margin
		move_direction.y *= -1
		hit_wall = true
	elif pos.y > screen_rect.size.y - margin:
		pos.y = screen_rect.size.y - margin
		move_direction.y *= -1
		hit_wall = true
		
	if hit_wall:
		position = pos
		decision_timer.start()

# --- 新增：通用寻路移动函数 ---
func handle_navigation_movement(_delta):
	# 1. 检查是否已到达
	if nav_agent.is_navigation_finished():
		velocity = Vector2.ZERO
		if current_state == DuckState.SEEK_FOOD:
			# 再次检查食物还在不在
			if is_instance_valid(target_food):
				eat_food()
			else:
				# 跑到了才发现食物没了，好气
				pick_new_state()
		elif current_state == DuckState.SEEK_WATER:
			drink_water()
		return

	# 2. 获取路径上的下一个点
	var next_path_pos = nav_agent.get_next_path_position()
	
	# 3. 计算朝向下一个点的速度
	var direction = position.direction_to(next_path_pos)
	velocity = direction * move_speed
	
	# 4. 移动
	move_and_slide()

func start_seeking_water():
	current_state = DuckState.SEEK_WATER
	target_water_source = find_nearest_water()
	decision_timer.stop()
	
	if target_water_source:
		# 告诉导航代理我们要去哪
		nav_agent.target_position = target_water_source.position

func start_seeking_food():
	var found_food = find_nearest_food()
	if found_food:
		current_state = DuckState.SEEK_FOOD
		target_food = found_food
		decision_timer.stop()
		
		# 告诉导航代理我们要去哪
		nav_agent.target_position = target_food.position
	else:
		pass

func handle_seek_food_logic():
	# 旧代码废弃，逻辑合并到了 handle_navigation_movement
	# 但我们需要保留这个函数名或者在 physics_process 里改掉调用
	# 建议直接在 physics_process 里统一调用 handle_navigation_movement
	pass 

func find_nearest_water() -> Node2D:
	var water_nodes = get_tree().get_nodes_in_group("Water")
	if water_nodes.is_empty():
		return null
		
	var nearest: Node2D = null
	var min_dist: float = INF # 无穷大
	
	for node in water_nodes:
		var dist = position.distance_to(node.position)
		if dist < min_dist:
			min_dist = dist
			nearest = node
			
	return nearest

func handle_seek_water_logic():
	# 重新计算方向指向水源
	move_direction = (target_water_source.position - position).normalized()
	
	if position.distance_to(target_water_source.position) < 20.0:
		drink_water()

func drink_water():
	current_thirst = max_thirst
	print("Duck drank water!")
	pick_new_state()

func find_nearest_food() -> Node2D:
	var food_nodes = get_tree().get_nodes_in_group("Food")
	if food_nodes.is_empty():
		return null
		
	var nearest: Node2D = null
	var min_dist: float = INF
	
	for node in food_nodes:
		# 必须检查 instance_valid，因为食物可能被别的鸭子吃掉了！
		if is_instance_valid(node):
			var dist = position.distance_to(node.position)
			if dist < min_dist:
				min_dist = dist
				nearest = node
	return nearest

# func handle_seek_food_logic():
# 	# 再次检查食物是否存在 (可能在走路过程中被删除了)
# 	if not is_instance_valid(target_food):
# 		pick_new_state() # 目标没了，重新决策
# 		return

# 	# 向食物移动
# 	move_direction = (target_food.position - position).normalized()
	
# 	# 吃到食物的距离判断
# 	if position.distance_to(target_food.position) < 15.0:
# 		eat_food()

func eat_food():
	# 恢复饥饿值 (增加 25%)
	current_hunger += max_hunger * 0.25
	if current_hunger > max_hunger:
		current_hunger = max_hunger
		
	print("Duck ate food! Yummy.")
	
	# 销毁食物物体
	target_food.queue_free()
	target_food = null
	
	# 吃完了，重新决策
	pick_new_state()

func update_animation():
	if velocity.x != 0:
		anim_sprite.flip_h = velocity.x < 0
		
	if current_state == DuckState.IDLE:
		anim_sprite.play("idle")
	else:
		# WANDER 和 SEEK_WATER 都播放走路动画
		anim_sprite.play("wander")

func _on_decision_timer_timeout():
	pick_new_state()

func pick_new_state():
	decision_timer.start()
	
	# 如果极度口渴，优先找水
	if current_thirst <= 30.0:
		start_seeking_water()
		return
	if current_hunger <= 40.0:
		start_seeking_food()
		# 如果地图上没食物，上面的函数不会切换状态，代码会继续往下执行变成随机移动
		# 只要切换成功了，直接 return
		if current_state == DuckState.SEEK_FOOD:
			return
	
	# 随机逻辑 (randf() 返回 0.0 到 1.0 的浮点数)
	if randf() > 0.6:
		current_state = DuckState.IDLE
		decision_timer.wait_time = randf_range(1.0, 3.0)
	else:
		current_state = DuckState.WANDER
		# 随机方向
		move_direction = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()
		decision_timer.wait_time = randf_range(0.5, 2.0)

func reset_talk_timer():
	talk_timer.wait_time = randf_range(10.0, 30.0)
	talk_timer.start()

func _on_talk_timer_timeout():
	speak()
	reset_talk_timer()

func speak():
	# 如果已经有气泡了，先别说了，或者覆盖
	if has_node("SpeechBubble"):
		return
		
	# 从全局数据获取内容
	var content = GameData.get_random_content()
	
	# 实例化气泡
	var bubble = bubble_scene.instantiate()
	add_child(bubble)
	
	# 填充数据
	bubble.setup(content.text, content.type, content.data)
	
	# 等待一帧，让 UI 布局引擎计算出气泡的高度
	await get_tree().process_frame 
	
	# 设置位置：X 居中，Y 在鸭子头顶上方
	# size.x / 2 是为了让气泡中心对准鸭子
	# size.y 是为了把气泡整个“抬”上去
	bubble.position = Vector2( -bubble.size.x / 2, -bubble.size.y - 30 ) 
	
	bubble.bubble_clicked.connect(_on_bubble_clicked)

func _on_bubble_clicked(type, data):
	match type:
		"memo":
			print("打开记事本")
			# 这里需要一种方式通知 MainGame 打开 UI
			# 最简单的是用 Global Event Bus，或者直接调用 Group
			get_tree().call_group("UI", "open_notepad")
			
		"news":
			print("打开新闻链接: ", data)
			OS.shell_open(data) # 调用系统默认浏览器打开网址
		"time":
			print("点击了时间，暂无操作")