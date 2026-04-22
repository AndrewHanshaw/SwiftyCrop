import SwiftUI

struct ProgressLayer: View {
  let configuration: SwiftyCropConfiguration
  let localizableTableName: String
  
  var body: some View {
    ZStack {
      configuration.colors.background.opacity(0.4)
        .ignoresSafeArea()
      
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
      if #available(iOS 26, macOS 26, *) {
        .glassEffect(
          .regular.tint(configuration.colors.background.opacity(0.8)),
          in: .rect(cornerRadius: 12)
        )
      } else {
        .frame(width: 120, height: 110)
        .background(configuration.colors.background.opacity(0.8))
        .cornerRadius(12)
      }
      .padding(.vertical, 5)
      .padding(.horizontal, 20)
    }
    .transition(.opacity)
  }
}

#Preview {
  ProgressLayer(configuration: .init(), localizableTableName: "Localizable")
}
