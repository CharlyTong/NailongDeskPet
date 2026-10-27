import Foundation

/// 朝向：走路方向
enum Direction {
    case left, right

    /// 随机取一个方向（50/50）
    static var random: Direction { Bool.random() ? .left : .right }
}

/// 桌宠状态机 —— 整个桌宠的"行为规则表"就这五种状态。
///
/// 为什么用 enum 而不是一堆 Bool（isWalking / isHappy...）？
/// enum 保证"同一时刻只能处于一种状态"，编译器还能在 switch 里
/// 强制你处理每一种情况（漏一个分支直接编译报错），不会出现
/// "既在走又在掉落"这种矛盾状态。
///
/// 转换规则（谁在什么条件下切到哪）集中在 PetEngine.tick() 里，
/// 改这一张表就能改变桌宠的性格。
enum PetState: Equatable {
    case idle       // 待机（原地发呆）
    case happy      // 被点击后的开心反应（1.5 秒后自动回 idle）
    case dragging   // 正被鼠标拖拽（位置完全由手指控制）
    case falling    // 被丢到半空，重力下落中
    case walk(Direction)  // 带参数的枚举值：左右共用一套素材，渲染时镜像翻转
}
