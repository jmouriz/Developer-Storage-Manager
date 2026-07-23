import AppKit
import SwiftUI

struct AboutView: View {
    private let repositoryURL = URL(string: "https://github.com/jmouriz/Developer-Storage-Manager")!

    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.4.4"
    }

    var body: some View {
        VStack(spacing: 18) {
            Image(nsImage: NSApplication.shared.applicationIconImage)
                .resizable()
                .scaledToFit()
                .frame(width: 128, height: 128)
                .accessibilityHidden(true)

            VStack(spacing: 5) {
                Text("Developer Storage Manager")
                    .font(.title.bold())
                Text(L10n.format("about.version", version))
                    .foregroundStyle(.secondary)
            }

            Divider()

            Grid(alignment: .leading, horizontalSpacing: 18, verticalSpacing: 11) {
                AboutRow(title: L10n.tr("about.date"), value: L10n.tr("about.date.value"))
                AboutRow(title: L10n.tr("about.author"), value: "Juan Manuel Mouriz")
                AboutRow(title: L10n.tr("about.license"), value: "MIT License")

                GridRow {
                    Text(L10n.tr("about.repository"))
                        .foregroundStyle(.secondary)
                    Link("GitHub", destination: repositoryURL)
                        .help(repositoryURL.absoluteString)
                }
            }

            Text(L10n.tr("about.description"))
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 360)

            Text("© 2026 Juan Manuel Mouriz")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(32)
        .frame(width: 460)
    }
}

private struct AboutRow: View {
    let title: String
    let value: String

    var body: some View {
        GridRow {
            Text(title)
                .foregroundStyle(.secondary)
            Text(value)
                .textSelection(.enabled)
        }
    }
}

struct AboutCommands: Commands {
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        CommandGroup(replacing: .appInfo) {
            Button(L10n.tr("about.menu")) {
                openWindow(id: "about")
            }
        }
    }
}
