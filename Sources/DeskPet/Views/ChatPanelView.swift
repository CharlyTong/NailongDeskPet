import SwiftUI

// ============================================================
// ChatPanelView —— 聊天窗口内容：标题栏 + 消息历史 + 输入框。
//
// 数据全部来自 PetEngine（单一数据源）：历史 messages、忙闲 isBusy。
// 这里只做展示和"把用户输入递给引擎"。
// ============================================================
struct ChatPanelView: View {
    @ObservedObject var engine: PetEngine
    let onClose: () -> Void
    @State private var draft = ""              // 输入框草稿
    @FocusState private var inputFocused: Bool // 控制输入框焦点

    var body: some View {
        VStack(spacing: 0) {
            // ---- 标题栏 ----
            HStack {
                Text("和桌宠聊天")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            Divider()

            // ---- 消息历史 ----
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(Array(engine.messages.enumerated()), id: \.offset) { i, msg in
                            ChatBubble(message: msg)
                                .id(i)
                        }
                        if engine.isBusy {
                            Text("思考中…")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 12)
                        }
                    }
                    .padding(12)
                }
                // 新消息到达时自动滚到底部
                .onChange(of: engine.messages.count) { _, _ in
                    if let last = engine.messages.indices.last {
                        proxy.scrollTo(last, anchor: .bottom)
                    }
                }
            }
            Divider()

            // ---- 输入区 ----
            HStack(spacing: 8) {
                TextField("说点什么…", text: $draft)
                    .textFieldStyle(.plain)
                    .focused($inputFocused)
                    .onSubmit(send)   // 回车直接发送
                Button("发送", action: send)
                    .buttonStyle(.borderedProminent)
                    .disabled(engine.isBusy
                              || draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(12)
        }
        .frame(width: 320, height: 420)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(.black.opacity(0.1)))
        .onAppear { inputFocused = true }  // 打开即聚焦，直接就能打字
        .onExitCommand { onClose() }       // Esc 关闭
    }

    private func send() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !engine.isBusy else { return }
        draft = ""
        engine.sendChat(text)
    }
}

/// 单条消息气泡：用户靠右蓝底，桌宠靠左灰底（和微信同样的视觉习惯）
private struct ChatBubble: View {
    let message: ChatMessage

    var body: some View {
        HStack {
            if message.role == "user" { Spacer(minLength: 40) }
            Text(message.content)
                .font(.system(size: 13))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    message.role == "user"
                        ? Color.blue.opacity(0.85)
                        : Color.gray.opacity(0.18),
                    in: RoundedRectangle(cornerRadius: 10)
                )
            if message.role != "user" { Spacer(minLength: 40) }
        }
    }
}
