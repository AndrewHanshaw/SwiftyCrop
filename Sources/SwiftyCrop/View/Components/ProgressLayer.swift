import SwiftUI

struct ProgressLayer: View {
  let configuration: SwiftyCropConfiguration
  let localizableTableName: String

  var body: some View {
    ZStack {
      configuration.colors.background.opacity(0.4)
        .ignoresSafeArea()

      styledProgressCard
    }
    .transition(.opacity)
  }

  private var styledProgressCard: some View {
    VStack(alignment: .center, spacing: 20) {
      ProgressView()
        .progressViewStyle(CircularProgressViewStyle(tint: configuration.colors.interactionInstructions))
        .scaleEffect(1.2)

      Text(
        configuration.texts.progressLayerText ??
          NSLocalizedString("processing_label", tableName: localizableTableName, bundle: .module, comment: "")
      )
      .font(.body)
      .foregroundColor(configuration.colors.interactionInstructions)
    }
    .padding(25)
    .modifier(ProgressCardStyle(background: configuration.colors.background))
    .padding(.vertical, 5)
    .padding(.horizontal, 20)
  }
}

#Preview {
  ProgressLayer(configuration: .init(), localizableTableName: "Localizable")
}

private struct ProgressCardStyle: ViewModifier {
  let background: Color

  func body(content: Content) -> some View {
    if #available(iOS 26, macOS 26, *) {
      content
        .glassEffect(
          .regular.tint(background.opacity(0.8)),
          in: .rect(cornerRadius: 12)
        )
    } else {
      content
        .frame(width: 120, height: 110)
        .background(background.opacity(0.8))
        .cornerRadius(12)
    }
  }
}
