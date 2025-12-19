using Godot;
using System;

// 命名空间对应你的目录结构 entities/ducks/scripts
namespace MyGame.Entities.Ducks
{
    public partial class Duck : CharacterBody2D
    {
        [Export] public float MoveSpeed = 50.0f;

        // 状态定义
        private enum DuckState
        {
            Idle,
            Wander
        }

        private DuckState _currentState;
        private Vector2 _moveDirection;
        private Random _random = new Random();
        
        // 引用类型改为 AnimatedSprite2D
        private AnimatedSprite2D _animSprite;
        private Timer _timer;

        public override void _Ready()
        {
            // 获取节点：根据你的操作，确认节点名称是否为 AnimSprite
            // 如果你没有重命名节点，默认可能是 "AnimatedSprite2D"
            _animSprite = GetNode<AnimatedSprite2D>("AnimSprite");
            _timer = GetNode<Timer>("DecisionTimer");

            _timer.Timeout += OnDecisionTimerTimeout;
            
            // 确保一开始动画就是播放的
            PickNewState();
            UpdateAnimation();
        }

        public override void _PhysicsProcess(double delta)
        {
            if (_currentState == DuckState.Wander)
            {
                Velocity = _moveDirection * MoveSpeed;
                MoveAndSlide();
            }
            else
            {
                Velocity = Vector2.Zero;
            }

            // 每一帧都根据当前状态和速度更新动画表现
            UpdateAnimation();
        }

        private void UpdateAnimation()
        {
            // 1. 处理水平翻转 (FlipH)
            // 只有当有横向速度时才改变朝向，这样停下时会保持最后的朝向
            if (Velocity.X != 0)
            {
                // 如果 Velocity.X < 0 (向左)，则 FlipH = true
                // 如果 Velocity.X > 0 (向右)，则 FlipH = false
                _animSprite.FlipH = Velocity.X < 0;
            }

            // 2. 处理动画播放
            if (_currentState == DuckState.Idle)
            {
                // 播放 idle 动画
                _animSprite.Play("idle");
            }
            else if (_currentState == DuckState.Wander)
            {
                // 播放 wander 动画
                _animSprite.Play("wander");
            }
        }

        private void OnDecisionTimerTimeout()
        {
            PickNewState();
        }

        private void PickNewState()
        {
            if (_random.NextDouble() > 0.6) // 调整概率：60% 几率发呆
            {
                _currentState = DuckState.Idle;
                _timer.WaitTime = _random.NextDouble() * 2.0 + 1.0;
            }
            else
            {
                _currentState = DuckState.Wander;
                
                // 简单的随机方向逻辑
                float x = (float)(_random.NextDouble() * 2 - 1);
                float y = (float)(_random.NextDouble() * 2 - 1);
                _moveDirection = new Vector2(x, y).Normalized();

                _timer.WaitTime = _random.NextDouble() * 1.5 + 0.5;
            }
            
            _timer.Start();
        }
    }
}