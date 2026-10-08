import SwiftUI

@main
@MainActor
struct CalendarClickApp: App {
    @StateObject private var model = AgendaModel()
    var body: some Scene {
        WindowGroup { AgendaView().environmentObject(model) }
    }
}
