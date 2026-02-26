import SwiftUI

struct PlayerRootView: View {
    @EnvironmentObject var sessionStore: PlayerSessionStore

    var body: some View {
        ZStack {
            if sessionStore.currentSource != nil {
                PlayerControlView()
            } else {
                PlayerOpenView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.black)
    }
}
