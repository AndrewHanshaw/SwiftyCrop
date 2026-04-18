import SwiftUI
#if canImport(UIKit)
import PhotosUI
#endif

struct CropView: View {
  @Environment(\.dismiss) private var dismiss
  @StateObject private var viewModel: CropViewModel

  @State private var isCropping: Bool = false
  @State private var containerSize: CGSize = .zero
  @State private var activeDragStart: CGPoint? = nil
  @State private var activeHandleEdge: HandleEdge = .none

  private let image: PlatformImage
  private let maskShape: MaskShape
  private let configuration: SwiftyCropConfiguration
  private let onCancel: (() -> Void)?
  private let onComplete: (PlatformImage?) -> Void
  private let localizableTableName: String

  init(
    image: PlatformImage,
    maskShape: MaskShape,
    configuration: SwiftyCropConfiguration,
    onCancel: (() -> Void)? = nil,
    onComplete: @escaping (PlatformImage?) -> Void
  ) {
    self.image = image
    self.maskShape = maskShape
    self.configuration = configuration
    self.onCancel = onCancel
    self.onComplete = onComplete
    _viewModel = StateObject(
      wrappedValue: CropViewModel(
        maskRadius: configuration.maskRadius,
        maxMagnificationScale: configuration.maxMagnificationScale,
        maskShape: maskShape,
        rectAspectRatio: configuration.rectAspectRatio,
        minAspectRatio: configuration.minAspectRatio,
        maxAspectRatio: configuration.maxAspectRatio
      )
    )
    localizableTableName = "Localizable"
  }
  
  // MARK: - Body
  var body: some View {
#if compiler(>=6.2) // Use this to prevent compiling of unavailable iOS 26 / macOS 26 APIs
    if configuration.usesLiquidGlassDesign,
       #available(iOS 26, visionOS 26.0, macOS 26.0, *) {
      buildLiquidGlassBody(configuration: configuration)
    } else {
      buildLegacyBody(configuration: configuration)
    }
#else
    buildLegacyBody(configuration: configuration)
#endif
  }

  @available(iOS 26, visionOS 26.0, macOS 26.0, *)
  private func buildLiquidGlassBody(configuration: SwiftyCropConfiguration) -> some View {
    NavigationView {
      ScrollView { // Dummy scroll view, necessary to trigger the blur effect behind the toolbar
        ZStack {
          cropImageView
          if isCropping {
            ProgressLayer(configuration: configuration, localizableTableName: localizableTableName)
          }
        }
      }
      .modifier(ScrollOffsetToolbarTriggerModifier()) // Force a scroll offset to trigger the scroll edge effect on appearance
      .scrollDisabled(true) // Don't actually want to scroll the view, just need this for the soft scroll edge effect
      .scrollEdgeEffectStyle(.soft, for: .top)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button {
            onCancel?()
            dismiss()
          } label: {
            Image(systemName: "xmark")
              .foregroundStyle(configuration.colors.cancelButton)
              .fontWeight(.semibold)
          }
        }
        if configuration.rotateImageWithButtons {
          ToolbarItem(placement: .principal) {
            HStack(spacing: 8) {
              Button {
                withAnimation {
                  viewModel.angle.degrees -= 90
                  viewModel.lastAngle = viewModel.angle
                }
              } label: {
                Image(systemName: "rotate.left")
                  .foregroundStyle(configuration.colors.rotateButton)
                  .fontWeight(.semibold)
              }
              Button {
                let numberOfFullCircles = Int(viewModel.angle.degrees / 360)
                let newValue = Double(numberOfFullCircles * 360)
                withAnimation {
                  viewModel.angle = Angle(degrees: newValue)
                  viewModel.lastAngle = viewModel.angle
                }
              } label: {
                Image(systemName: "arrow.uturn.backward.circle")
                  .foregroundStyle(configuration.colors.resetRotationButton)
                  .fontWeight(.semibold)
              }
              .opacity(viewModel.angle.degrees.truncatingRemainder(dividingBy: 360) == 0 ? 0.7 : 1)
              .disabled(viewModel.angle.degrees.truncatingRemainder(dividingBy: 360) == 0)
              Button {
                withAnimation {
                  viewModel.angle.degrees += 90
                  viewModel.lastAngle = viewModel.angle
                }
              } label: {
                Image(systemName: "rotate.right")
                  .foregroundStyle(configuration.colors.rotateButton)
                  .fontWeight(.semibold)
              }
            }
          }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button {
            Task {
              await MainActor.run { isCropping = true }
              let result = cropImage()
              await MainActor.run {
                onComplete(result)
                dismiss()
                isCropping = false
              }
            }
          } label: {
            Image(systemName: "checkmark")
              .foregroundStyle(configuration.colors.saveButton)
              .fontWeight(.semibold)
          }
          .disabled(isCropping)
        }
      }
      .navigationBarBackground(configuration.colors.background)
    }
  }
  
  private func buildLegacyBody(configuration: SwiftyCropConfiguration) -> some View {
    NavigationStack {
      ZStack {
        configuration.colors.background.ignoresSafeArea()
        cropImageView
        if isCropping {
          Legacy_ProgressLayer(configuration: configuration, localizableTableName: localizableTableName)
        }
      }
      .navigationBarDisplayModeInline()
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button {
            onCancel?()
            dismiss()
          } label: {
            Text(
              configuration.texts.cancelButton ??
                NSLocalizedString("cancel_button", tableName: localizableTableName, bundle: .module, comment: "")
            )
            .font(configuration.fonts.cancelButton)
            .foregroundStyle(configuration.colors.cancelButton)
          }
          .disabled(isCropping)
        }
        ToolbarItem(placement: .principal) {
          if configuration.rotateImageWithButtons {
            HStack(spacing: 8) {
              Button {
                withAnimation {
                  viewModel.angle.degrees -= 90
                  viewModel.lastAngle = viewModel.angle
                }
              } label: {
                Image(systemName: "rotate.left")
                  .foregroundStyle(configuration.colors.rotateButton)
              }
              Button {
                let numberOfFullCircles = Int(viewModel.angle.degrees / 360)
                let newValue = Double(numberOfFullCircles * 360)
                withAnimation {
                  viewModel.angle = Angle(degrees: newValue)
                  viewModel.lastAngle = viewModel.angle
                }
              } label: {
                Image(systemName: "arrow.uturn.backward.circle")
                  .foregroundStyle(configuration.colors.resetRotationButton)
              }
              .opacity(viewModel.angle.degrees.truncatingRemainder(dividingBy: 360) == 0 ? 0.3 : 1)
              .disabled(viewModel.angle.degrees.truncatingRemainder(dividingBy: 360) == 0)
              Button {
                withAnimation {
                  viewModel.angle.degrees += 90
                  viewModel.lastAngle = viewModel.angle
                }
              } label: {
                Image(systemName: "rotate.right")
                  .foregroundStyle(configuration.colors.rotateButton)
              }
            }
          } else {
            Text(
              configuration.texts.interactionInstructions ??
                NSLocalizedString("interaction_instructions", tableName: localizableTableName, bundle: .module, comment: "")
            )
            .font(configuration.fonts.interactionInstructions)
            .foregroundStyle(configuration.colors.interactionInstructions)
          }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button {
            Task {
              await MainActor.run { isCropping = true }
              let result = cropImage()
              await MainActor.run {
                onComplete(result)
                dismiss()
                isCropping = false
              }
            }
          } label: {
            Text(
              configuration.texts.saveButton ??
                NSLocalizedString("save_button", tableName: localizableTableName, bundle: .module, comment: "")
            )
            .font(configuration.fonts.saveButton)
            .foregroundStyle(configuration.colors.saveButton)
          }
          .disabled(isCropping)
        }
      }
      .navigationBarBackground(configuration.colors.background)
    }
  }
  
  // MARK: - Gestures
  private var magnificationGesture: some Gesture {
    MagnificationGesture()
      .onChanged { value in
        let sensitivity: CGFloat = 0.1 * configuration.zoomSensitivity
        let scaledValue = (value.magnitude - 1) * sensitivity + 1
        
        let maxScaleValues = viewModel.calculateMagnificationGestureMaxValues()
        viewModel.scale = min(max(scaledValue * viewModel.lastScale, maxScaleValues.0), maxScaleValues.1)
        
        updateOffset()
      }
      .onEnded { _ in
        viewModel.lastScale = viewModel.scale
        viewModel.lastOffset = viewModel.offset
      }
  }
  
  private var dragGesture: some Gesture {
    DragGesture()
      .onChanged { value in
        // Determine edge once per gesture, at first touch-down.
        if activeDragStart != value.startLocation {
          activeDragStart = value.startLocation
          activeHandleEdge = handleEdge(for: value.startLocation)
        }
        switch activeHandleEdge {
        case .top:
          viewModel.resizeMaskByHeightDelta(-2 * value.translation.height)
          updateOffset()
          return
        case .bottom:
          viewModel.resizeMaskByHeightDelta(2 * value.translation.height)
          updateOffset()
          return
        case .left:
          viewModel.resizeMaskByWidthDelta(-2 * value.translation.width)
          updateOffset()
          return
        case .right:
          viewModel.resizeMaskByWidthDelta(2 * value.translation.width)
          updateOffset()
          return
        case .none:
          break
        }
        let maxOffsetPoint = viewModel.calculateDragGestureMax()
        let newX = min(
          max(value.translation.width + viewModel.lastOffset.width, -maxOffsetPoint.x),
          maxOffsetPoint.x
        )
        let newY = min(
          max(value.translation.height + viewModel.lastOffset.height, -maxOffsetPoint.y),
          maxOffsetPoint.y
        )
        viewModel.offset = CGSize(width: newX, height: newY)
      }
      .onEnded { _ in
        activeDragStart = nil
        activeHandleEdge = .none
        viewModel.lastOffset = viewModel.offset
        viewModel.lastMaskHeight = viewModel.maskSize.height
        viewModel.lastMaskWidth = viewModel.maskSize.width
      }
  }
  
  private var rotationGesture: some Gesture {
    RotationGesture()
      .onChanged { value in
        viewModel.angle = viewModel.lastAngle + value
      }
      .onEnded { _ in
        viewModel.lastAngle = viewModel.angle
      }
  }
  
  // MARK: - UI Components
  private var cropImageView: some View {
    ZStack {
      PlatformImageView(image: image)
        .rotationEffect(viewModel.angle)
        .scaleEffect(viewModel.scale)
        .offset(viewModel.offset)
        .opacity(0.5)
        .overlay(
          GeometryReader { geometry in
            Color.clear
              .onAppear {
                viewModel.updateMaskDimensions(for: geometry.size)
              }
          }
        )

      PlatformImageView(image: image)
        .rotationEffect(viewModel.angle)
        .scaleEffect(viewModel.scale)
        .offset(viewModel.offset)
        .mask(
          MaskShapeView(maskShape: maskShape)
            .frame(width: viewModel.maskSize.width, height: viewModel.maskSize.height)
        )

      if maskShape == .rectangle && configuration.allowAspectRatioResizing {
        maskHandlesOverlay
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(
      GeometryReader { geo in
        Color.clear.onAppear { containerSize = geo.size }
      }
    )
    .simultaneousGesture(magnificationGesture)
    .simultaneousGesture(dragGesture)
    .simultaneousGesture(configuration.rotateImage ? rotationGesture : nil)
  }
  
  private var maskHandlesOverlay: some View {
    Group {
      ZStack {
        Rectangle()
          .stroke(
            configuration.colors.cropHandle.opacity(0.8),
            style: StrokeStyle(lineWidth: 1.5, dash: [6, 3])
          )
          .frame(width: viewModel.maskSize.width, height: viewModel.maskSize.height)

        // Top handle
        Capsule()
          .fill(configuration.colors.cropHandle)
          .frame(width: 40, height: 8)
          .shadow(radius: 2)
          .offset(y: -viewModel.maskSize.height / 2)

        // Bottom handle
        Capsule()
          .fill(configuration.colors.cropHandle)
          .frame(width: 40, height: 8)
          .shadow(radius: 2)
          .offset(y: viewModel.maskSize.height / 2)

        // Left handle
        Capsule()
          .fill(configuration.colors.cropHandle)
          .frame(width: 8, height: 40)
          .shadow(radius: 2)
          .offset(x: -viewModel.maskSize.width / 2)

        // Right handle
        Capsule()
          .fill(configuration.colors.cropHandle)
          .frame(width: 8, height: 40)
          .shadow(radius: 2)
          .offset(x: viewModel.maskSize.width / 2)
      }
      .allowsHitTesting(false)
    }
  }

  // MARK: - Helpers

  private enum HandleEdge {
    case top, bottom, left, right, none
  }

  private func handleEdge(for point: CGPoint) -> HandleEdge {
    guard maskShape == .rectangle && configuration.allowAspectRatioResizing else {
      return .none
    }
    let centerX = containerSize.width / 2
    let centerY = containerSize.height / 2
    let halfW = viewModel.maskSize.width / 2
    let halfH = viewModel.maskSize.height / 2

    // Top edge: 80pt wide × 44pt tall hit zone
    if abs(point.x - centerX) <= 40, abs(point.y - (centerY - halfH)) <= 22 {
      return .top
    }
    // Bottom edge: 80pt wide × 44pt tall hit zone
    if abs(point.x - centerX) <= 40, abs(point.y - (centerY + halfH)) <= 22 {
      return .bottom
    }
    // Left edge: 44pt wide × 80pt tall hit zone
    if abs(point.x - (centerX - halfW)) <= 22, abs(point.y - centerY) <= 40 {
      return .left
    }
    // Right edge: 44pt wide × 80pt tall hit zone
    if abs(point.x - (centerX + halfW)) <= 22, abs(point.y - centerY) <= 40 {
      return .right
    }
    return .none
  }

  private func updateOffset() {
    let maxOffsetPoint = viewModel.calculateDragGestureMax()
    let newX = min(max(viewModel.offset.width, -maxOffsetPoint.x), maxOffsetPoint.x)
    let newY = min(max(viewModel.offset.height, -maxOffsetPoint.y), maxOffsetPoint.y)
    viewModel.offset = CGSize(width: newX, height: newY)
    viewModel.lastOffset = viewModel.offset
  }
  
  private func cropImage() -> PlatformImage? {
    var editedImage: PlatformImage = image
    if configuration.rotateImage || configuration.rotateImageWithButtons {
      if let rotatedImage: PlatformImage = viewModel.rotate(
        editedImage,
        viewModel.lastAngle
      ) {
        editedImage = rotatedImage
      }
    }
    if configuration.cropImageCircular && maskShape == .circle {
      return viewModel.cropToCircle(editedImage)
    } else if maskShape == .rectangle {
      return viewModel.cropToRectangle(editedImage)
    } else {
      return viewModel.cropToSquare(editedImage)
    }
  }
  
  // MARK: - Mask Shape View
  private struct MaskShapeView: View {
    let maskShape: MaskShape

    var body: some View {
      Group {
        switch maskShape {
        case .circle:
          Circle()
        case .square, .rectangle:
          Rectangle()
        }
      }
    }
  }
}

// MARK: - Scroll offset toolbar trigger (needed to activate scroll edge blur behind toolbar)

@available(iOS 26, visionOS 26.0, macOS 26.0, *)
private struct ScrollOffsetToolbarTriggerModifier: ViewModifier {
  @State private var scrollPosition = ScrollPosition(y: 20)

  func body(content: Content) -> some View {
    content
      .scrollPosition($scrollPosition)
  }
}

// MARK: - Platform-conditional toolbar helpers

private extension View {
  @ViewBuilder
  func navigationBarDisplayModeInline() -> some View {
    #if canImport(UIKit)
      navigationBarTitleDisplayMode(.inline)
    #else
      self
    #endif
  }

  @ViewBuilder
  func navigationBarBackground(_ color: Color) -> some View {
    #if canImport(UIKit)
      toolbarBackground(color, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
    #else
      self
    #endif
  }
}

// MARK: - Platform Image View
struct PlatformImageView: View {
  let image: PlatformImage

  var body: some View {
    #if canImport(UIKit)
    Image(uiImage: image)
      .resizable()
      .scaledToFit()
    #elseif canImport(AppKit)
    Image(nsImage: image)
      .resizable()
      .scaledToFit()
    #endif
  }
}
