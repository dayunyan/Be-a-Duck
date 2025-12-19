using Godot;
using System;
using System.Linq; // 需要这个来做简单的数组排序

namespace MyGame.Entities.Ducks
{
    public partial class Duck : CharacterBody2D
    {
        [Export] public float MoveSpeed = 50.0f;

        // --- 新增：需求系统属性 ---
        [Export] public float MaxThirst = 100.0f;
        [Export] public float ThirstDecayRate = 5.0f; // 每秒口渴减少的值
        public float CurrentThirst { get; private set; }
        
        // 饥饿值暂时只写变量，逻辑先留空
        [Export] public float MaxHunger = 100.0f; 
        [Export] public float HungerDecayRate = 2.0f;
        public float CurrentHunger { get; private set; }

        private enum DuckState
        {
            Idle,
            Wander,
            SeekWater // 新增：找水状态
        }

        private DuckState _currentState;
        private Vector2 _moveDirection;
        private Node2D _targetWaterSource; // 锁定的水源目标
        
        private Random _random = new Random();
        private AnimatedSprite2D _animSprite;
        private Timer _timer;
        private Rect2 _screenRect;

        private ProgressBar _thirstBar;
        private ProgressBar _hungerBar;

        public override void _Ready()
        {
            _animSprite = GetNode<AnimatedSprite2D>("AnimSprite");
            _timer = GetNode<Timer>("DecisionTimer");
            _timer.Timeout += OnDecisionTimerTimeout;

            // 获取 UI 节点
            _thirstBar = GetNode<ProgressBar>("StatusUI/ThirstBar");
            _hungerBar = GetNode<ProgressBar>("StatusUI/HungerBar");
            
            // 初始化 UI 最大值 (防止你在编辑器里没设对)
            _thirstBar.MaxValue = MaxThirst;
            _hungerBar.MaxValue = MaxHunger;

            // 初始化满状态
            CurrentThirst = MaxThirst;
            CurrentHunger = MaxHunger;

            PickNewState();
            UpdateAnimation();
        }

        public override void _PhysicsProcess(double delta)
        {
            _screenRect = GetViewportRect();
            
            // --- 新增：自然衰减 ---
            // 只有不在喝水状态（找水时还是会渴）时才衰减，或者简化为一直衰减
            CurrentThirst -= ThirstDecayRate * (float)delta;
            CurrentHunger -= HungerDecayRate * (float)delta;

            // --- 新增：更新 UI ---
            // 每一帧把数值同步给 UI
            _thirstBar.Value = CurrentThirst;
            _hungerBar.Value = CurrentHunger;

            // --- 新增：检测是否口渴 ---
            // 如果口渴值低且当前不在找水，强制进入找水状态
            if (CurrentThirst <= 30.0f && _currentState != DuckState.SeekWater)
            {
                StartSeekingWater();
            }

            // 状态机行为
            switch (_currentState)
            {
                case DuckState.Wander:
                    Velocity = _moveDirection * MoveSpeed;
                    MoveAndSlide();
                    CheckBounds();
                    break;

                case DuckState.Idle:
                    Velocity = Vector2.Zero;
                    break;

                case DuckState.SeekWater:
                    HandleSeekWaterState();
                    break;
            }

            UpdateAnimation();
        }

        // --- 新增：找水逻辑 ---
        private void StartSeekingWater()
        {
            _currentState = DuckState.SeekWater;
            _targetWaterSource = FindNearestWater();
            
            // 找水时不需要随机计时器打断，先暂停它
            _timer.Stop();
        }

        private Node2D FindNearestWater()
        {
            // 获取所有属于 "Water" 组的节点
            var waterNodes = GetTree().GetNodesInGroup("Water");
            
            if (waterNodes.Count == 0) return null; // 没水喝，惨

            // 简单的查找最近算法
            Node2D nearest = null;
            float minDistance = float.MaxValue;

            foreach (Node2D node in waterNodes)
            {
                float dist = Position.DistanceTo(node.Position);
                if (dist < minDistance)
                {
                    minDistance = dist;
                    nearest = node;
                }
            }
            return nearest;
        }

        private void HandleSeekWaterState()
        {
            if (_targetWaterSource == null)
            {
                // 地图上没水，只能切回发呆，防止卡死
                PickNewState();
                return;
            }

            // 向目标移动
            Vector2 direction = (_targetWaterSource.Position - Position).Normalized();
            Velocity = direction * MoveSpeed;
            MoveAndSlide();

            // 检查距离：如果离水源小于 20 像素，算喝到了
            if (Position.DistanceTo(_targetWaterSource.Position) < 20.0f)
            {
                DrinkWater();
            }
        }

        private void DrinkWater()
        {
            // 喝水逻辑
            CurrentThirst = MaxThirst;
            GD.Print("Duck drank water! Thirst reset.");

            // 喝完后，重新开始瞎逛
            PickNewState();
        }
        // -----------------------

        private void CheckBounds()
        {
            // (保持之前的代码不变)
            Vector2 pos = Position;
            bool hitWall = false;
            if (pos.X < 16) { pos.X = 16; _moveDirection.X *= -1; hitWall = true; }
            else if (pos.X > _screenRect.Size.X - 16) { pos.X = _screenRect.Size.X - 16; _moveDirection.X *= -1; hitWall = true; }
            if (pos.Y < 16) { pos.Y = 16; _moveDirection.Y *= -1; hitWall = true; }
            else if (pos.Y > _screenRect.Size.Y - 16) { pos.Y = _screenRect.Size.Y - 16; _moveDirection.Y *= -1; hitWall = true; }
            if (hitWall) { Position = pos; _timer.Start(); }
        }

        private void UpdateAnimation()
        {
            if (Velocity.X != 0) _animSprite.FlipH = Velocity.X < 0;

            if (_currentState == DuckState.Idle) _animSprite.Play("idle");
            else if (_currentState == DuckState.Wander || _currentState == DuckState.SeekWater) _animSprite.Play("wander"); // 找水也是走路动作
        }

        private void OnDecisionTimerTimeout() => PickNewState();

        private void PickNewState()
        {
            // 每次做决定前，确保计时器是开启的
            _timer.Start();

            // 如果已经很渴了，优先找水 (防止随机状态覆盖了找水需求)
            if (CurrentThirst <= 30.0f)
            {
                StartSeekingWater();
                return;
            }

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
        }
    }
}