import AppCore
import DesignSystem
import SwiftUI
import Tiko

public struct NewRoomView: View {
    @State private var model: NewRoomViewModel

    public init(model: NewRoomViewModel) {
        _model = State(initialValue: model)
    }

    public var body: some View {
        VStack(spacing: 0) {
            HStack {
                CloseButton("Back to home") { model.close() }
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    switch model.step {
                    case .checking, .opening:
                        Spinner("Opening a room").frame(maxWidth: .infinity).padding(.top, 80)
                    case .signIn:
                        HStack(alignment: .bottom, spacing: 12) {
                            TikoView(mood: .wave, size: 72)
                            Text("One quick step before your first friend duel.")
                                .font(.display(24)).foregroundStyle(Theme.text)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        SignInForm(model: model.signIn)
                    case let .failed(message):
                        ErrorNote(message) { Task { await model.open() } }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 20)
                .padding(.bottom, 40)
            }
            .scrollIndicators(.hidden)
        }
        .task { await model.load() }
    }
}
