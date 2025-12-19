using Godot;
using System;

public partial class Duck : CharacterBody2D
{
	// 定义移动速度
	[Export] public float MoveSpeed = 50.0f;

	// 定义鸭子的状态枚举
	private enum DuckState
	{
		Idle,   // 发呆
		Wander  // 瞎逛
	}

	private DuckState _currentState;
	private Vector2 _moveDirection;
	private Random _random = new Random();
	private AnimatedSprite2D _sprite;
	private Timer _timer;

	public override void _Ready()
	{
		// 获取子节点引用
		_sprite = GetNode<AnimatedSprite2D>("AnimatedSprite2D");
		_timer = GetNode<Timer>("DecisionTimer");

		// 连接 Timer 的 Timeout 信号到我们的方法
		// 相当于 Python 的 self.timer.timeout.connect(self._on_timer_timeout)
		_timer.Timeout += OnDecisionTimerTimeout;

		// 初始随机动作
		PickNewState();
	}

	public override void _PhysicsProcess(double delta)
	{
		if (_currentState == DuckState.Wander)
		{
			// 设置内置的 Velocity 属性
			Velocity = _moveDirection * MoveSpeed;
			
			// 翻转 Sprite 方向：如果向左走，FlipH = true
			if (Velocity.X != 0)
			{
				_sprite.FlipH = Velocity.X < 0;
			}

			// 执行物理移动 (Godot 4 只需要调用这个，它会自动使用 Velocity)
			MoveAndSlide();
		}
		else
		{
			// 如果是发呆，通过摩擦力慢慢停下来（可选平滑效果）
			Velocity = Vector2.Zero;
		}
	}

	// 这是决策大脑：每隔几秒钟思考一次“我要干嘛”
	private void OnDecisionTimerTimeout()
	{
		PickNewState();
	}

	private void PickNewState()
	{
		// 随机决定是发呆还是移动 (50% 概率)
		if (_random.NextDouble() > 0.5)
		{
			_currentState = DuckState.Idle;
			// 发呆时间随机一点，0.5秒 到 2.5秒之间
			_timer.WaitTime = _random.NextDouble() * 2.0 + 0.5;
		}
		else
		{
			_currentState = DuckState.Wander;
			// 随机生成一个方向向量 (-1 到 1 之间)
			float x = (float)(_random.NextDouble() * 2 - 1);
			float y = (float)(_random.NextDouble() * 2 - 1);
			_moveDirection = new Vector2(x, y).Normalized(); // 归一化，保证斜着走速度不会变快
			
			// 移动时间短一点，防止跑出屏幕太远
			_timer.WaitTime = _random.NextDouble() * 1.5 + 0.5;
		}
		
		// 实际上 Timer 需要重新开始计时（如果 WaitTime 变了）
		// Godot 的 Timer 修改 WaitTime 不会自动重置，除非手动 Start
		_timer.Start();
	}
}