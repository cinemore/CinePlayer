import SwiftUI

struct PlaySettingPicker: View {
    let seconds = [5, 10, 15, 20, 25, 30, 40, 50, 60]
    @Binding var selection: Int
    var title: LocalizedStringKey

    init(_ title: LocalizedStringKey, selection: Binding<Int>) {
        self.title = title
        _selection = selection
    }

    var body: some View {
        Picker(selection: $selection) {
            ForEach(seconds, id: \.self) { second in
                Text("\(second)s")
                    .tag(second)
                    #if os(tvOS)
                        .f31r()
                        .frame(width: 150)
                    #else
                        .f14r()
                    #endif
            }
        } label: {
            Text(title)
        }
        .labelStyle(.titleAndIcon)
        .pickerStyle(.menu)
    }
}
