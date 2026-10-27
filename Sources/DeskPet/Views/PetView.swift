import SwiftUI

// ============================================================
// PetView —— 桌宠的"脸面"：只读引擎数据来画图，不写任何逻辑。
//
// 分层纪律：视图层永远不决定"做什么"，只决定"长什么样"。
// 好处：改外观不会碰坏行为，改行为不用动外观。
// ============================================================
struct PetView: View {
    // @ObservedObject = "我要观察这个对象，它的 @Published 属性一变就重画我"
    @ObservedObject var engine: PetEngine

    var body: some View {
        ZStack {
            content
                // 朝向镜像：素材只有一套朝右的走路图，朝左走时水平翻转即可。
                // 注意翻转只作用在"内容"上，手势挂在外层容器，坐标系不被污染。
                .scaleEffect(x: engine.facingLeft ? -1 : 1, y: 1)
        }
        .frame(width: PetConfig.petSize.width, height: PetConfig.petSize.height)
        // ★ 单一手势策略（踩坑后的修复）★
        // 原来 onTapGesture + DragGesture 并存，靠 SwiftUI 自动消歧：
        // 真人点击总有几像素手抖，一旦超过 minimumDistance 就被 DragGesture
        // 抢走当拖拽，tap 永远不触发 → "点了没反应"。合成鼠标(零抖动)才能触发，
        // 这就是"机器测试全过、人手必失败"的经典陷阱。
        // 现在只留一个手势：minimumDistance 0 = 按下瞬间手势即开始，
        // 松手时自己判定——总位移 <6pt 是戳一戳，≥6pt 是真拖拽。
        // 规则自己定，永不打架，连"零位移的完美点击"也不漏。
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in engine.dragMoved() }
                .onEnded { _ in engine.dragEnded() }
        )
    }

    /// 有素材放素材图，没素材画占位小猫
    @ViewBuilder
    private var content: some View {
        if let image = engine.currentFrameImage {
            Image(nsImage: image)
                .resizable()
                .scaledToFit()
        } else {
            placeholderFace
        }
    }

    // MARK: - 占位形象：色块小猫（素材就位前的替身）
    //
    // 用不同颜色区分状态，还用帧号做了轻微起伏 ——
    // 这样即使没有任何素材，也能直观验证"动画引擎确实在转"。
    private var placeholderFace: some View {
        let isWalking: Bool = {
            if case .walk = engine.state { return true }
            return false
        }()
        // 偶数帧沉、奇数帧浮：走路起伏大，发呆呼吸轻
        let bob: CGFloat = engine.frameIndex.isMultiple(of: 2) ? 0 : (isWalking ? 3 : 1)

        return ZStack {
            RoundedRectangle(cornerRadius: 28)
                .fill(bodyColor)
            HStack(spacing: 22) {          // 两个眼睛跟着帧号一起"起伏"
                Circle().fill(.black).frame(width: 10, height: 10).offset(y: bob)
                Circle().fill(.black).frame(width: 10, height: 10).offset(y: bob)
            }
            .offset(y: -8)
            Capsule()                       // 嘴
                .fill(.black.opacity(0.75))
                .frame(width: 16, height: 4)
                .offset(y: 14)
        }
    }

    private var bodyColor: Color {
        switch engine.state {
        case .idle:     return .teal      // 青色 = 待机
        case .walk:     return .blue      // 蓝色 = 走路
        case .happy:    return .pink      // 粉色 = 被点击很开心
        case .dragging: return .gray      // 灰色 = 被拎起来
        case .falling:  return .orange    // 橙色 = 掉落中
        }
    }
}
