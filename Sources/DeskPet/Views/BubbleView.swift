import SwiftUI

// ============================================================
// BubbleView —— 气泡外观（显示在 BubblePanel 里）。
//
// 引擎控制"何时显示/何时隐藏/显示什么"，这里只负责好看。
// ============================================================
/// 漫画风对话气泡形状：圆角身体 + 一条指向桌宠的小尾巴。
/// 一个 Path 里画两个子图形，填充时会自动"并集"，
/// 所以尾巴和身体之间不会露缝，也不用在衔接处描边。
struct SpeechBalloon: Shape {
    var tailHeight: CGFloat = 11
    var tailWidth: CGFloat = 15

    func path(in rect: CGRect) -> Path {
        var p = Path()
        // 身体：占据除尾巴以外的区域
        let body = CGRect(x: 0, y: 0, width: rect.width, height: rect.height - tailHeight)
        p.addPath(Path(roundedRect: body, cornerRadius: 13))
        // 尾巴：正下方中间的小三角，尖端朝下（桌宠头顶就在那里）
        let cx = rect.midX
        p.move(to: CGPoint(x: cx - tailWidth / 2, y: body.maxY - 5))
        p.addLine(to: CGPoint(x: cx + 1, y: rect.maxY))          // 尖端
        p.addLine(to: CGPoint(x: cx + tailWidth / 2, y: body.maxY - 5))
        p.closeSubpath()
        return p
    }
}

struct BubbleView: View {
    @ObservedObject var engine: PetEngine

    var body: some View {
        // 气泡从窗口底部冒出来（桌宠头顶就在窗口正下方 8pt 处）
        ZStack(alignment: .bottom) {
            if let text = engine.bubbleText {
                Text(text)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    // ★ 深色模式坑：不写死颜色时，SwiftUI 默认文字色跟随系统
                    //   外观（浅色=黑、深色=白）。气泡底已硬编码白色 → 深色模式
                    //   下白字白底，字"消失"。底写死了，字也必须写死。
                    .foregroundColor(.black)
                    // 防模型输出超长（temperature 1.8 偶发失控）撑爆 76pt 高的窗口
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)   // 文本按内容换行
                    .frame(maxWidth: PetEngine.bubbleSize.width - 32, alignment: .leading)
                    .padding(.horizontal, 12)
                    .padding(.top, 9)
                    .padding(.bottom, 9 + 11)   // 多垫 11pt 给尾巴留位置
                    .background(
                        SpeechBalloon().fill(.white)
                            .shadow(color: .black.opacity(0.18), radius: 3, y: 1)
                    )
                    .transition(.scale(scale: 0.6, anchor: .bottom)
                        .combined(with: .opacity))
            }
        }
        // text 一变就播放弹性动画：像从头顶"啵"地弹出来
        .animation(.spring(response: 0.32, dampingFraction: 0.62),
                   value: engine.bubbleText)
        .frame(maxWidth: .infinity, maxHeight: .infinity,
               alignment: .bottom)   // 贴住窗口底部 = 贴住桌宠头顶
    }
}
