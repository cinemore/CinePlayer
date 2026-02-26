import SwiftUI

#if !os(tvOS)
    /// 扩展 Double 类型，添加一个方法用于将当前值从一个范围转换到另一个范围
    extension Double {
        func convert(fromRange: (Double, Double), toRange: (Double, Double)) -> Double {
            var value = self
            value -= fromRange.0
            value /= Double(fromRange.1 - fromRange.0)
            value *= toRange.1 - toRange.0
            value += toRange.0
            return value
        }
    }

    /// 定义一个自定义滑块视图
    struct CustomSlider<Component: View>: View {
        // MARK: Lifecycle

        init(
            value: Binding<Int>,
            range: (Int, Int),
            knobWidth: CGFloat?,
            onEditingChanged: @escaping (Bool) -> Void,
            _ viewBuilder: @escaping (CustomSliderData) -> Component
        ) {
            _value = value
            self.range = range
            self.viewBuilder = viewBuilder
            self.knobWidth = knobWidth
            self.onEditingChanged = onEditingChanged
        }

        // MARK: Internal

        @Binding var value: Int

        var range: (Int, Int)
        var knobWidth: CGFloat?
        var onEditingChanged: (Bool) -> Void
        let viewBuilder: (CustomSliderData) -> Component

        var body: some View {
            GeometryReader { geometry in
                view(geometry: geometry)
            }
        }

        // MARK: Private

        private func view(geometry: GeometryProxy) -> some View {
            let frame = geometry.frame(in: .local)
            // 拖动手势 - 支持拖动和点击（minimumDistance: 0 表示也响应点击）
            let drag = DragGesture(minimumDistance: 0)
                .onChanged { drag in
                    Task { @MainActor in
                        let value = newValue(drag, frame)
                        self.value = Int(value)
                        onEditingChanged(true)
                    }
                }
                .onEnded { drag in
                    Task { @MainActor in
                        let value = newValue(drag, frame)
                        self.value = Int(value)
                        onEditingChanged(false)
                    }
                }

            // 计算进度比例 (0.0 到 1.0)
            let progressRatio = Double(value - range.0) / Double(range.1 - range.0)

            // 锚点中心在进度条上的位置 (0 到 frame.width)
            let knobCenterX = frame.width * CGFloat(progressRatio)

            // 锚点尺寸
            let knobSize = CGSize(width: knobWidth ?? frame.height, height: frame.height)

            let sliderData = CustomSliderData(
                progressRatio: progressRatio,
                knobCenterX: knobCenterX,
                knobSize: knobSize,
                frameSize: frame.size
            )

            return ZStack {
                // 透明背景确保整个区域可点击 - 使用极低透明度而不是完全透明
                Rectangle()
                    .fill(Color.white.opacity(0.001)) // 使用极低透明度，视觉上透明但能接收点击
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                // 用户自定义UI
                viewBuilder(sliderData)
            }
            .gesture(drag)
            .contentShape(Rectangle())
        }

        private func newValue(_ drag: DragGesture.Value, _ frame: CGRect) -> Double {
            // 获取拖动的绝对位置（支持点击和拖动）
            let dragX = drag.startLocation.x + drag.translation.width

            // 将拖动位置限制在进度条范围内 (0 到 frame.width)
            let clampedX = max(0, min(frame.width, dragX))

            // 转换为进度比例 (0.0 到 1.0)
            let progressRatio = clampedX / frame.width

            // 转换为实际值
            return Double(range.0) + (Double(range.1 - range.0) * Double(progressRatio))
        }
    }

    /// 传递给用户的滑块数据
    struct CustomSliderData {
        let progressRatio: Double
        let knobCenterX: CGFloat
        let knobSize: CGSize
        let frameSize: CGSize
    }
#endif
