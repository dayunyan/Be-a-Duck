using Godot;
using System;

namespace MyGame.Entities.Ducks
{
    public partial class Duck : CharacterBody2D
    {
        [Export] public float MoveSpeed = 50.0f;

        private enum DuckState { Idle, Wander }
        private DuckState _currentState;
        private Vector2 _moveDirection;
        private Random _random = new Random();
        private AnimatedSprite2D _animSprite;
        private Timer _timer;

        // 获取屏幕大小的辅助变量
        private Rect2 _screenRect;

        public override void _Ready()
        {
            _animSprite = GetNode<AnimatedSprite2D>("AnimSprite");
            _timer = GetNode<Timer>("DecisionTimer");
            _timer.Timeout += OnDecisionTimerTimeout;

            PickNewState();
            UpdateAnimation();
        }

        public override void _PhysicsProcess(double delta)
        {
            // 每一帧都获取最新的视口大小（为了适应窗口缩放）
            _screenRect = GetViewportRect();

            if (_currentState == DuckState.Wander)
            {
                Velocity = _moveDirection * MoveSpeed;
                MoveAndSlide();

                // 移动后，检查是否出界
                CheckBounds();
            }
            else
            {
                Velocity = Vector2.Zero;
            }

            UpdateAnimation();
        }

        // 新增：边界检查逻辑
        private void CheckBounds()
        {
            // 获取鸭子当前位置
            Vector2 pos = Position;
            bool hitWall = false;

            // 检查 X 轴 (左右边界)
            // 这里的 16 是一个缓冲距离，防止鸭子半个身子卡进屏幕边缘
            if (pos.X < 16) 
            {
                pos.X = 16;
                _moveDirection.X *= -1; // 撞左墙，X反向
                hitWall = true;
            }
            else if (pos.X > _screenRect.Size.X - 16)
            {
                pos.X = _screenRect.Size.X - 16;
                _moveDirection.X *= -1; // 撞右墙，X反向
                hitWall = true;
            }

            // 检查 Y 轴 (上下边界)
            if (pos.Y < 16)
            {
                pos.Y = 16;
                _moveDirection.Y *= -1; // 撞上墙，Y反向
                hitWall = true;
            }
            else if (pos.Y > _screenRect.Size.Y - 16)
            {
                pos.Y = _screenRect.Size.Y - 16;
                _moveDirection.Y *= -1; // 撞下墙，Y反向
                hitWall = true;
            }

            // 如果撞墙了，更新位置并重置计时器，让它在新方向走一会儿
            if (hitWall)
            {
                Position = pos;
                // 撞墙后立刻刷新计时器，防止它刚回头又立刻因为计时器到期而变向
                _timer.Start(); 
            }
        }

        private void UpdateAnimation()
        {
            if (Velocity.X != 0) _animSprite.FlipH = Velocity.X < 0;

            if (_currentState == DuckState.Idle) _animSprite.Play("idle");
            else if (_currentState == DuckState.Wander) _animSprite.Play("wander");
        }

        private void OnDecisionTimerTimeout() => PickNewState();

        private void PickNewState()
        {
            if (_random.NextDouble() > 0.6)
            {
                _currentState = DuckState.Idle;
                _timer.WaitTime = _random.NextDouble() * 2.0 + 1.0;
            }
            else
            {
                _currentState = DuckState.Wander;
                float x = (float)(_random.NextDouble() * 2 - 1);
                float y = (float)(_random.NextDouble() * 2 - 1);
                _moveDirection = new Vector2(x, y).Normalized();
                _timer.WaitTime = _random.NextDouble() * 1.5 + 0.5;
            }
            _timer.Start();
        }
    }
}