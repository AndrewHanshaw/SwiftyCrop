import SwiftUI

struct SizePreferenceKey: PreferenceKey {
  static let defaultValue: CGSize = .zero
  static func reduce(value: inout CGSize, nextValue: () -> CGSize) { value = nextValue() }
}

@available(iOS 26, visionOS 26.0, macOS 26.0, *)
struct ScrollOffsetToolbarTriggerModifier: ViewModifier {
  @State private var scrollPosition = ScrollPosition(y: 20)
  func body(content: Content) -> some View {
    ScrollView {
      content
    }
    .contentMargins(.top, 20, for: .scrollContent)
    .scrollPosition($scrollPosition)
    .scrollDisabled(true)
    .scrollEdgeEffectStyle(.soft, for: .top)
  }
}

extension View {
  // Scroll offset toolbar trigger extension. Only applies to iOS 26+

  @ViewBuilder
  func scrollOffsetToolbarTrigger() -> some View {
    if #available(iOS 26, visionOS 26.0, macOS 26.0, *) {
      #if os(iOS)
        self.modifier(ScrollOffsetToolbarTriggerModifier())
      #else
        self
      #endif
    } else {
      self
    }
  }

  @ViewBuilder
  func tintedGlassEffect() -> some View {
    if #available(iOS 26, visionOS 26.0, macOS 26.0, *) {
      #if os(iOS)
        self.buttonStyle(GlassProminentButtonStyle())
      #else
        self.glassEffect(.regular.tint(Color.accentColor).interactive())
      #endif
    } else {
      self
    }
  }

  /// Calls `perform` whenever this view's size changes (including after first layout).
  /// Uses `PreferenceKey` so it's compatible with all supported OS versions.
  @ViewBuilder
  func onSizeChange(_ perform: @escaping (CGSize) -> Void) -> some View {
    if #available(iOS 26, visionOS 26.0, macOS 26.0, *) {
      self
    } else {
      background(
        GeometryReader { geo in
          Color.clear.preference(key: SizePreferenceKey.self, value: geo.size)
        }
      )
      .onPreferenceChange(SizePreferenceKey.self, perform: perform)
    }
  }
}
