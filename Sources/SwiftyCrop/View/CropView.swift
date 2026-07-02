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
  @State private var activeHandleEdge: HandleEdge? = nil

  private let image: PlatformImage
  @State private var maskShape: MaskShape
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
    ZStack {
      cropImageView
      
      if isCropping {
        ProgressLayer(configuration: configuration, localizableTableName: localizableTableName)
      }
    }
    // Scrolls the view up slightly so the blurred background of the toolbar is shown on a non-scrolling view
    // Helps with contrast between the toolbar title and the content behind it
    .scrollOffsetToolbarTrigger()
    .toolbar {
      toolbarView
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
        case nil:
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
        activeHandleEdge = nil
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
              .onSizeChange { newSize in
                viewModel.updateMaskDimensions(for: newSize)
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
        Color.clear
          .onAppear { containerSize = geo.size }
          .onSizeChange { newSize in containerSize = newSize }
      }
    )
    .simultaneousGesture(magnificationGesture)
    .simultaneousGesture(dragGesture)
    .simultaneousGesture(configuration.rotateImage ? rotationGesture : nil)
  }

  @ToolbarContentBuilder
  private var toolbarView: some ToolbarContent {
    ToolbarItem(placement: .cancellationAction) {
      Button {
        onCancel?()
        dismiss()
      } label: {
        Label(
          configuration.texts.cancelButton ??
            NSLocalizedString("cancel_button", tableName: localizableTableName, bundle: .module, comment: ""),
          systemImage: "xmark"
        )
        .toolbarButtonLabelStyle()
        .font(configuration.fonts.cancelButton)
        .foregroundStyle(configuration.colors.cancelButton)
      }
      .disabled(isCropping)
    }
    if configuration.rotateImageWithButtons {
      RotationControlsView(
        angle: $viewModel.angle,
        lastAngle: $viewModel.lastAngle,
        configuration: configuration
      )
    }
    if configuration.allowMaskShapeToggle {
      MaskShapeControlsView(
        maskShape: $maskShape,
        configuration: configuration,
        onSelect: { viewModel.updateMaskShape($0) }
      )
    }
    ToolbarItem(placement: .principal) {
      Text(
        configuration.texts.interactionInstructions ??
          NSLocalizedString("interaction_instructions", tableName: localizableTableName, bundle: .module, comment: "")
      )
      .padding(.horizontal)
      .font(configuration.fonts.interactionInstructions)
      .foregroundStyle(configuration.colors.interactionInstructions)
    }
    #if !os(visionOS)
    if #available(iOS 26, macOS 26, *) {
      ToolbarSpacer(.fixed)
    }
    #endif
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
        Label(
          configuration.texts.saveButton ??
            NSLocalizedString("save_button", tableName: localizableTableName, bundle: .module, comment: ""),
          systemImage: "checkmark"
        )
        .toolbarButtonLabelStyle()
        .font(configuration.fonts.saveButton)
        .foregroundStyle(configuration.colors.saveButton)
      }
      .disabled(isCropping)
      .tintedGlassEffect()
    }
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
    case top, bottom, left, right
  }

  private func handleEdge(for point: CGPoint) -> HandleEdge? {
    guard maskShape == .rectangle && configuration.allowAspectRatioResizing else {
      return nil
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
    return nil
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

// MARK: - Mask Shape Controls View
struct MaskShapeControlsView: ToolbarContent {
  @Binding var maskShape: MaskShape
  let configuration: SwiftyCropConfiguration
  let onSelect: (MaskShape) -> Void

  var body: some ToolbarContent {
    ToolbarItem(placement: .navigation) {
      Menu {
        shapeButtons()
      } label: {
          Label("Change Crop Shape", systemImage: "circle.on.square")
            .foregroundStyle(configuration.colors.rotateButton)
      }
    }
  }

  @ViewBuilder
  private func shapeButtons() -> some View {
    Button {
      maskShape = .circle
      onSelect(.circle)
    } label: {
      Label("Circle", systemImage: "circle")
    }
    .foregroundStyle(configuration.colors.rotateButton)

    Button {
      maskShape = .square
      onSelect(.square)
    } label: {
      Label("Square", systemImage: "square")
    }
    .foregroundStyle(configuration.colors.rotateButton)

    Button {
      maskShape = .rectangle
      onSelect(.rectangle)
    } label: {
      Label("Rectangle", systemImage: "rectangle")
    }
    .foregroundStyle(configuration.colors.rotateButton)
  }
}

// MARK: - Rotation Controls View
struct RotationControlsView: ToolbarContent {
  @Binding var angle: Angle
  @Binding var lastAngle: Angle
  let configuration: SwiftyCropConfiguration

  @State private var showRotationPopover: Bool = false

  var body: some ToolbarContent {
    #if os(iOS) || os(visionOS)
    ToolbarItem(placement: .navigation) {
      if #available(iOS 16.4, visionOS 1.0, *) {
        Button {
          showRotationPopover = true
        } label: {
          Image(systemName: "ellipsis.circle")
            .foregroundStyle(configuration.colors.rotateButton)
        }
        .popover(isPresented: $showRotationPopover) {
          HStack(spacing: 12) {
            rotationButtons(onDismiss: { showRotationPopover = false })
            .labelStyle(.iconOnly)
          }
          .padding()
          .presentationCompactAdaptation(.popover)
        }
      } else {
        Menu {
          rotationButtons()
        } label: {
          Image(systemName: "ellipsis.circle")
        }
        .foregroundStyle(configuration.colors.rotateButton)
      }

    }
    #else
      ToolbarItemGroup(placement: .navigation) {
        rotationButtons()
        .labelStyle(.iconOnly)
      }
    #endif
  }

  @ViewBuilder
  private func rotationButtons(onDismiss: (() -> Void)? = nil) -> some View {
    Button {
      withAnimation {
        angle.degrees -= 90
        lastAngle = angle
      }
    } label: {
      Label("Rotate Left", systemImage: "rotate.left")
    }
    .foregroundStyle(configuration.colors.rotateButton)

    Button {
      let numberOfFullCircles = Int(angle.degrees / 360)
      let newValue = Double(numberOfFullCircles * 360)
      withAnimation {
        angle = Angle(degrees: newValue)
        lastAngle = angle
      }
      onDismiss?()
    } label: {
      Label("Reset Rotation", systemImage: "arrow.uturn.backward.circle")
    }
    .foregroundStyle(configuration.colors.resetRotationButton)
    .opacity(isResetDisabled ? 0.3 : 1)
    .disabled(isResetDisabled)

    Button {
      withAnimation {
        angle.degrees += 90
        lastAngle = angle
      }
    } label: {
      Label("Rotate Right", systemImage: "rotate.right")
    }
    .foregroundStyle(configuration.colors.rotateButton)
  }

  private var isResetDisabled: Bool {
    angle.degrees.truncatingRemainder(dividingBy: 360) == 0
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
