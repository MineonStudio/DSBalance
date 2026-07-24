import AppKit

// 仅菜单栏运行，不显示 Dock 图标
NSApplication.shared.setActivationPolicy(.accessory)

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
