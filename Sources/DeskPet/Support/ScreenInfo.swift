import AppKit

/// 屏幕几何工具 —— 只读数值，不截屏，所以不需要任何系统权限。
enum ScreenInfo {
    /// 主屏"可见区域" = 整屏减去顶部菜单栏和 Dock。
    /// 好处：Dock 移到屏幕左侧/底部时，visibleFrame 会自动缩小，
    /// 桌宠自然就不会走到 Dock 底下去了，不用我们写任何 Dock 判断逻辑。
    /// （缺省值只是极端兜底，正常机器上 NSScreen.main 永远存在）
    static var visibleFrame: NSRect {
        NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
    }
}
