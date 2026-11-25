import SwiftUI

enum Style {
    static let mint = Color(red: 0.68, green: 0.89, blue: 0.73)
    static let card = Color(white: 0.075)
    static let line = Color(white: 0.17)
    static let muted = Color(white: 0.67)
    static let motion = Animation.spring(response: 0.28, dampingFraction: 0.82)
}

extension View {
    func panel() -> some View {
        padding(16)
            .background(Style.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay { RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Style.line) }
    }

    func listSurface() -> some View {
        listStyle(.plain).scrollContentBackground(.hidden).background(Color.black)
    }

    func panelRow() -> some View {
        listRowInsets(EdgeInsets(top: 5, leading: 18, bottom: 5, trailing: 18))
            .listRowSeparator(.hidden).listRowBackground(Color.clear)
    }

    func workoutRow() -> some View {
        listRowInsets(EdgeInsets(top: 3, leading: 16, bottom: 3, trailing: 16))
            .listRowSeparator(.hidden).listRowBackground(Color.clear)
    }

    func reporting(_ failure: Binding<String?>) -> some View {
        alert("Couldn’t complete that change", isPresented: Binding(
            get: { failure.wrappedValue != nil },
            set: { if !$0 { failure.wrappedValue = nil } }
        )) { Button("OK") { failure.wrappedValue = nil } } message: {
            Text(failure.wrappedValue ?? "")
        }
    }
}

struct PrimaryButton: View {
    var title: String
    var icon: String
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack {
                Text(title)
                Spacer()
                Image(systemName: icon)
            }
            .font(.headline)
            .padding(.horizontal, 18)
            .frame(maxWidth: .infinity, minHeight: 54)
            .background(Style.mint, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .foregroundStyle(.black)
            .contentShape(Rectangle())
        }.buttonStyle(.plain).accessibilityLabel(title)
    }
}

struct IconControl: View {
    let title: String
    let icon: String
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: icon).font(.body.weight(.semibold))
                .frame(minWidth: 44, minHeight: 44).contentShape(Rectangle())
        }.accessibilityLabel(title).buttonStyle(.plain)
    }
}

struct SectionTitle: View {
    let text: String
    var body: some View {
        Text(text).font(.title3.bold()).foregroundStyle(.white)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct NameSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var value: String
    @State private var failure: String?
    @FocusState private var focused: Bool
    let title: String
    let prompt: String
    let save: @MainActor (String) throws -> Void

    init(_ title: String, prompt: String, initial: String = "", save: @escaping @MainActor (String) throws -> Void) {
        self.title = title
        self.prompt = prompt
        self.save = save
        _value = State(initialValue: initial)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 18) {
                TextField(prompt, text: $value).focused($focused)
                    .submitLabel(.done).onSubmit(commit).panel()
                PrimaryButton(title: "Save", icon: "checkmark", action: commit)
                    .disabled(value.trimmed.isEmpty).opacity(value.trimmed.isEmpty ? 0.45 : 1)
                Spacer()
            }
            .padding(18).navigationTitle(title).navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
            .onAppear { focused = true }.reporting($failure)
        }.presentationDetents([.medium, .large])
    }

    private func commit() {
        guard !value.trimmed.isEmpty else { return }
        do { try save(value.trimmed); dismiss() }
        catch { failure = error.localizedDescription }
    }
}

// A stack of machined plates, drawn at the card's native resolution.
struct Plates: View {
    var body: some View {
        Canvas { context, size in
            let scale = min(size.width / 142, size.height / 104)
            context.translateBy(x: size.width / 2, y: size.height / 2)
            context.scaleBy(x: scale, y: scale)
            context.rotate(by: .degrees(-22))
            for i in 0..<3 {
                let x = CGFloat(i - 1) * 17
                let rim = CGRect(x: x - 33, y: -43, width: 66, height: 86)
                let face = Path(ellipseIn: rim)
                context.fill(face, with: .linearGradient(Gradient(colors: [Color(white: 0.33), Color(white: 0.09), Color(white: 0.19)]),
                                                        startPoint: CGPoint(x: x - 33, y: -37), endPoint: CGPoint(x: x + 23, y: 32)))
                context.stroke(face, with: .color(Color(white: 0.36)), lineWidth: 1)
                for inset in [4, 9] {
                    context.stroke(Path(ellipseIn: rim.insetBy(dx: CGFloat(inset), dy: CGFloat(inset))),
                                   with: .color(Color(white: 0.11)), lineWidth: 1.5)
                }
                let hub = Path(ellipseIn: CGRect(x: x - 8, y: -11, width: 16, height: 22))
                context.fill(hub, with: .color(.black))
                context.stroke(hub, with: .color(Color(white: 0.44)), lineWidth: 2)
            }
        }.accessibilityHidden(true)
    }
}
