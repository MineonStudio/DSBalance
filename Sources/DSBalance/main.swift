import AppKit

// 禁用 Dock 图标，仅菜单栏运行
NSApplication.shared.setActivationPolicy(.accessory)

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
