# iOS 15 兼容修改与验证记录

基于 EasyTier/EasyTier-iOS 的 main 快照：
`17c74db5e1248a5e4242bfa71892aed6ec210ec3`。

## 修改范围

- 主 App、Network Extension、Shared 静态库、Widget Extension 的 Debug/Release 最低版本统一为 iOS 15.0。
- 导航：iOS 16+ 使用 NavigationStack；iOS 15 使用 stack 风格 NavigationView 和绑定式 NavigationLink。
- 表单：为 LabeledContent、分组表单样式、滚动收键盘和多行输入提供版本分支。iOS 15 多行内容使用 TextEditor；状态页使用单列布局。
- 新建/重命名网络改用表单 sheet，避免 iOS 15 忽略 SwiftUI alert 中的 TextField。
- 改用旧系统支持的工具栏位置、Button/Label、动画和 Task.sleep(nanoseconds:)。
- App Intents 增加可用性约束。iOS 15/16 状态小组件只能显示状态并点击打开 App；iOS 17+ 保留交互按钮；控制中心小组件和已有快捷指令仍要求较新系统。
- 设置页不再显示旧系统无法应用的网络排除开关。
- iOS 使用由原项目 PNG 生成的传统 LegacyAppIcon 图标集；macOS 保留原来的 Icon Composer 图标。
- 移除 Xcode 27.1 专用的竖向工具栏与边距 API，采用普通工具栏及固定列间距，以便 Xcode 26.3 构建。
- SystemConfiguration.framework 从固定的 iPhoneOS26.4 SDK 路径改为 SDKROOT 相对路径。
- Rust 构建抽为 ci_scripts/build-core.sh，使用 --locked，向 iOS 原生依赖传递部署版本，并纠正 x86_64 模拟器的 Rust target。
- TOMLKit 锁定版本 0.6.0 的 Package.swift 支持 iOS 13，不需要更换该依赖；Rust EasyTier 依赖仍为上游锁定的 v2.6.4。

## GitHub Actions

Nightly workflow 使用公开托管的 macos-15 runner 和 Xcode 26.3。该组合在修改时已从 actions/runner-images 的官方 macos-15 软件清单确认；托管镜像未来可能移除旧 Xcode，届时需更新路径。

流程依次执行：安装 Rust/protobuf、shell 语法检查、原有生命周期与配置选择测试、产物检查器单元测试、Release archive、检查产物、ad-hoc 签名、打包、上传 artifact。推送 main 或手动在 main 运行还会更新 nightly release；PR 只验证和上传 artifact。

归档显式指定 IPHONEOS_DEPLOYMENT_TARGET=15.0。ci_scripts/verify-ios15.cjs 检查主 App 和两个扩展是否存在、各 bundle 的 MinimumOSVersion、所有 Mach-O 的最低系统 load command，以及 AppIntents/SwiftUICore 是否被错误地强链接。构建日志若出现链接了较新系统对象文件的警告，也会停止打包。

代码签名沿用上游的 TrollStore 方案，不需要 Apple 开发者凭据。降低系统门槛不会让普通未签名安装自动可用；需要匹配设备系统的 TrollStore 环境，或另外使用具备 Network Extension 权限的有效签名配置。

构建目录为仓库内 .build，包含 DerivedData、SwiftPM checkout、Cargo 下载缓存、archive、日志、签名中间文件与 export；Rust target 保留在 Core/target。GitHub runner 自带的 Xcode、rustup 等工具仍使用 runner 环境，不影响本机。

## 已做与未做的验证

已在 Windows 本地完成：

- YAML 解析及 Xcode project.pbxproj 解析；检查 8 个部署目标均为 15.0。
- 检查器的 3 组 Node 测试：版本边界、现代/旧式 load command、平台、多架构和弱链接。
- git diff --check、源代码兼容性审查、图标资源完整性检查。

尚未完成：真实 Xcode 编译、链接、IPA 安装与 iOS 15 真机 VPN 测试。Windows 无 Xcode/Apple SDK，且此次没有上传仓库或触发远程 Actions。这里的静态检查不等于已经编译通过。

上传后必须确认 Nightly 为绿色，产物检查步骤通过，再安装验证：

1. 启动、三页切换；新建/重命名/删除配置；返回导航和 iPad 横竖屏。
2. 编辑长密钥、多行 ACL、Web 管理地址；保存并重启确认持久化。
3. 创建 VPN 配置、连接、分配地址、节点互访、断开、切后台与恢复。
4. 日志导出、配置导入导出；本地配置模式和 Web 管理模式分别测试。
5. iOS 15 小组件显示和点击打开；较新系统小组件连接按钮。

如果失败，下载 Actions 中的 ios15-build-diagnostics artifact（若已进入 archive，会包含 archive.log / xcresult），连同失败步骤日志排查。
