import SwiftUI

#if os(iOS)
    let ToolbarLeading = ToolbarItemPlacement.navigationBarLeading
    let ToolbarTrailing = ToolbarItemPlacement.navigationBarTrailing
#else
    let ToolbarLeading = ToolbarItemPlacement.navigation
    let ToolbarTrailing = ToolbarItemPlacement.primaryAction
#endif

extension View {
    func decimalKeyboardType() -> some View {
#if os(iOS)
        return self.keyboardType(.decimalPad)
#else
        return self
#endif
    }
    
    func numberKeyboardType() -> some View {
#if os(iOS)
        return self.keyboardType(.numberPad)
#else
        return self
#endif
    }
    
    func adaptiveNavigationBarTitleInline() -> some View {
#if os(iOS)
        return self.navigationBarTitleDisplayMode(.inline)
#else
        return self
#endif
    }
    
    func adaptiveNoTextInputAutocapitalization() -> some View {
#if os(iOS)
        return self.textInputAutocapitalization(.never)
#else
        return self
#endif
    }

    @ViewBuilder
    func adaptiveToolbarLabelStyle(padding: CGFloat) -> some View {
        self.labelStyle(.titleAndIcon).padding(padding)
    }
}

extension ToolbarContent {
    // Keep the call sites portable to the Xcode 26 SDK used by CI.
    @ToolbarContentBuilder
    func adaptiveVerticalPreferred() -> some ToolbarContent {
        self
    }
}

/// iOS 15 has NavigationView rather than NavigationStack. A stack style also
/// prevents a second, implicit split view around our own iPad columns.
struct CompatibleNavigationStack<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        if #available(iOS 16.0, macOS 13.0, *) {
            NavigationStack { content() }
        } else {
#if os(iOS)
            NavigationView { content() }.navigationViewStyle(.stack)
#else
            NavigationView { content() }
#endif
        }
    }
}

struct CompatibleLabeledContent<Label: View, Content: View>: View {
    private let label: Label
    private let content: Content

    init(@ViewBuilder content: () -> Content, @ViewBuilder label: () -> Label) {
        self.content = content()
        self.label = label()
    }

    var body: some View {
        if #available(iOS 16.0, macOS 13.0, *) {
            LabeledContent { content } label: { label }
        } else {
            HStack(alignment: .firstTextBaseline) {
                label
                Spacer(minLength: 12)
                content
            }
        }
    }
}

extension CompatibleLabeledContent where Label == Text {
    init(_ title: LocalizedStringKey, @ViewBuilder content: () -> Content) {
        self.init(content: content, label: { Text(title) })
    }
}

extension CompatibleLabeledContent where Label == Text, Content == Text {
    init(_ title: LocalizedStringKey, value: String) {
        self.init(content: { Text(verbatim: value) }, label: { Text(title) })
    }
}

struct CompatibleMultilineTextField: View {
    let title: LocalizedStringKey
    @Binding var text: String
    let prompt: Text?

    init(_ title: LocalizedStringKey, text: Binding<String>, prompt: Text? = nil) {
        self.title = title
        _text = text
        self.prompt = prompt
    }

    var body: some View {
        if #available(iOS 16.0, macOS 13.0, *) {
            TextField(title, text: $text, prompt: prompt, axis: .vertical)
        } else {
            // TextEditor preserves multiline editing and long keys on iOS 15.
            TextEditor(text: $text)
                .frame(minHeight: 64)
                .accessibilityLabel(Text(title))
        }
    }
}

extension View {
    @ViewBuilder
    func compatibleGroupedForm() -> some View {
        if #available(iOS 16.0, macOS 13.0, *) {
            self.formStyle(.grouped)
        } else {
            self // Form already uses grouped styling on iOS 15.
        }
    }

    @ViewBuilder
    func compatibleDismissKeyboard() -> some View {
        if #available(iOS 16.0, macOS 13.0, *) {
            self.scrollDismissesKeyboard(.immediately)
        } else {
            self
        }
    }

    @ViewBuilder
    func compatibleMultilineLimit() -> some View {
        if #available(iOS 16.0, macOS 13.0, *) {
            self.lineLimit(2...4)
        } else {
            self
        }
    }

    /// SwiftUI alert text fields do not appear on iOS 15. Use an editable sheet
    /// on every supported OS so creating and renaming profiles always works.
    func profileNameSheet(_ title: LocalizedStringKey, isPresented: Binding<Bool>,
                          text: Binding<String>, saveTitle: LocalizedStringKey,
                          onSave: @escaping () -> Void) -> some View {
        self.sheet(isPresented: isPresented) {
            CompatibleNavigationStack {
                Form {
                    TextField("config_name", text: text)
                        .adaptiveNoTextInputAutocapitalization()
                        .disableAutocorrection(true)
                }
                .navigationTitle(title)
                .adaptiveNavigationBarTitleInline()
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("common.cancel") { isPresented.wrappedValue = false }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button(saveTitle) {
                            onSave()
                            isPresented.wrappedValue = false
                        }
                        .disabled(text.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }
        }
    }
}

