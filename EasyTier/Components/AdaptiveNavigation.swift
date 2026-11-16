import SwiftUI

struct AdaptiveNavigation<PrimaryView, SecondaryView, Enum>: View where PrimaryView: View, SecondaryView: View, Enum: Identifiable & Hashable {
#if os(macOS)
    let sizeClass = UserInterfaceSizeClass.compact
#else
    @Environment(\.horizontalSizeClass) var sizeClass
#endif
    @ViewBuilder var primaryColumn: PrimaryView
    @ViewBuilder var secondaryColumn: SecondaryView
    @Binding var showNav: Enum?
    
    init(_ primary: PrimaryView, _ secondary: SecondaryView, showNav: Binding<Enum?>) {
        primaryColumn = primary
        secondaryColumn = secondary
        _showNav = showNav
    }
    
    var body: some View {
        Group {
            if sizeClass == .regular {
                HStack(spacing: 0) {
                    primaryColumn
                        .columnGutter(.trailing)
                        .frame(maxWidth: columnMaxWidth)
                    secondaryColumn
                        .columnGutter(.leading)
                }
            } else {
                primaryColumn
            }
        }
        .adaptiveNavigationDestination(item: (sizeClass == .compact ? $showNav : .constant(nil)), destination: { secondaryColumn })
    }
}

extension View {
    func columnGutter(_ edge: HorizontalEdge, minimum: CGFloat = 10) -> some View {
        modifier(ColumnGutter(edge: edge, minimum: minimum))
    }

    @ViewBuilder
    func adaptiveNavigationDestination<Enum: Identifiable & Hashable, Destination: View>(
        item: Binding<Enum?>,
        @ViewBuilder destination: @escaping () -> Destination
    ) -> some View {
        if #available(iOS 17.0, macOS 14.0, *) {
            self.navigationDestination(item: item) { _ in
                destination()
            }
        } else if #available(iOS 16.0, macOS 13.0, *) {
            self.navigationDestination(
                isPresented: Binding(
                    get: { item.wrappedValue != nil },
                    set: { isPresented in
                        if !isPresented {
                            item.wrappedValue = nil
                        }
                    }
                )
            ) {
                destination()
            }
        } else {
            self.background(
                NavigationLink(isActive: Binding(
                    get: { item.wrappedValue != nil },
                    set: { if !$0 { item.wrappedValue = nil } }
                )) {
                    destination()
                } label: {
                    EmptyView()
                }
                .hidden()
            )
        }
    }
}

private struct ColumnGutter: ViewModifier {
    let edge: HorizontalEdge
    let minimum: CGFloat

    func body(content: Content) -> some View {
        content
            .safeAreaInset(edge: edge, spacing: 0) {
                Color.clear.frame(width: minimum)
            }
    }
}
