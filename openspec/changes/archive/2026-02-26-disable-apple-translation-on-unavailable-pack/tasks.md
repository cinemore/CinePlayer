## 1. Unsupported Fallback Policy

- [x] 1.1 在 Apple 语言对 `unsupported` 时自动将翻译模式切到 `off`
- [x] 1.2 为 `unsupported -> off` 追加策略日志
- [x] 1.3 更新 unsupported 弹窗文案，明确翻译已关闭

## 2. Dismiss-Without-Install Fallback Policy

- [x] 2.1 在语言包下载弹窗关闭时复查语言对安装状态
- [x] 2.2 若仍未安装则自动切 `off` 并记录日志
- [x] 2.3 若已安装则保留模式并记录调试日志

## 3. Verification

- [x] 3.1 运行并通过 7 平台构建：iOS / iOS Simulator / tvOS / tvOS Simulator / macOS / visionOS / visionOS Simulator
- [x] 3.2 自检 unsupported 与取消下载路径的日志与模式收敛逻辑
