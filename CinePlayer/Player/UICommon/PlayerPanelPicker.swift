import CinePlayerSDK
import SwiftUI

extension EnvironmentValues {
    @Entry var usesPlayerPanelForm: Bool = false
}

/// 菜单选择器在自定义表单中显式绘制字段名，原生 Form 保持系统布局。
struct PlayerPanelPicker<Selection: Hashable, Options: View>: View {
    @Environment(\.usesPlayerPanelForm) private var usesPlayerPanelForm
    private let title: LocalizedStringKey
    @Binding private var selection: Selection
    private let options: Options

    init(_ title: LocalizedStringKey, selection: Binding<Selection>, @ViewBuilder content: () -> Options) {
        self.title = title
        _selection = selection
        options = content()
    }

    var body: some View {
        if usesPlayerPanelForm {
            HStack {
                Text(title)
                Spacer(minLength: 12)
                Picker(title, selection: $selection) { options }
                    .labelsHidden()
            }
        } else {
            Picker(title, selection: $selection) { options }
        }
    }
}
