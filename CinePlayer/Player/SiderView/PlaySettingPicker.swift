import SwiftUI

struct PlaySettingPicker: View {
    private var seconds: [Int] {
        #if os(tvOS)
        [5, 10, 15, 20, 30, 45, 60]
        #else
        [5, 10, 15, 20, 25, 30, 40, 50, 60]
        #endif
    }
    @Binding var selection: Int
    var title: LocalizedStringKey

    init(_ title: LocalizedStringKey, selection: Binding<Int>) {
        self.title = title
        _selection = selection
    }

    var body: some View {
        PlayerPanelPicker(title, selection: $selection) {
            ForEach(seconds, id: \.self) { second in
                Text("\(second)s")
                    .tag(second)
            }
        }
        .labelStyle(.titleAndIcon)
        .pickerStyle(.menu)
    }
}
