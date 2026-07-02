import SwiftUI
import SwiftyCrop

#if canImport(UIKit)
typealias PlatformImage = UIImage
#elseif canImport(AppKit)
import AppKit
typealias PlatformImage = NSImage
#endif

struct ContentView: View {
  @State private var showImageCropper: Bool = false
  @State private var selectedImage: PlatformImage?
  @State private var selectedShape: MaskShape = .square
  @State private var rectAspectRatio: PresetAspectRatios = .fourToThree
  @State private var cropImageCircular: Bool
  @State private var rotateImage: Bool
  @State private var rotateImageWithButtons: Bool
  @State private var maxMagnificationScale: CGFloat
  @State private var maskRadius: CGFloat
  @State private var zoomSensitivity: CGFloat
  @State private var allowAspectRatioResizing: Bool
  @State private var minAspectRatio: CGFloat
  @State private var maxAspectRatio: CGFloat
  @FocusState private var textFieldFocused: Bool
  @EnvironmentObject private var cropSession: CropSession
  #if os(macOS)
    @Environment(\.openWindow) private var openWindow
  #endif
  
  enum PresetAspectRatios: String, CaseIterable {
    case fourToThree = "4:3"
    case sixteenToNine = "16:9"
    
    func getValue() -> CGFloat {
      switch self {
      case .fourToThree:
        4/3
        
      case .sixteenToNine:
        16/9
      }
    }
  }
  
  init() {
    let defaultConfiguration = SwiftyCropConfiguration()
    _cropImageCircular = State(initialValue: defaultConfiguration.cropImageCircular)
    _rotateImage = State(initialValue: defaultConfiguration.rotateImage)
    _rotateImageWithButtons = State(initialValue: defaultConfiguration.rotateImageWithButtons)
    _maxMagnificationScale = State(initialValue: defaultConfiguration.maxMagnificationScale)
    _maskRadius = State(initialValue: defaultConfiguration.maskRadius)
    _zoomSensitivity = State(initialValue: defaultConfiguration.zoomSensitivity)
    _allowAspectRatioResizing = State(initialValue: defaultConfiguration.allowAspectRatioResizing)
    _minAspectRatio = State(initialValue: defaultConfiguration.minAspectRatio)
    _maxAspectRatio = State(initialValue: defaultConfiguration.maxAspectRatio)
  }
  
  var body: some View {
    VStack {
      Spacer()
      
      Group {
        if let selectedImage = selectedImage {
          DemoPlatformImageView(image: selectedImage)
            .aspectRatio(contentMode: .fit)
            .cornerRadius(8)
        } else {
          ProgressView()
        }
      }
      .scaledToFit()
      .padding()
      
      Spacer()
      
      GroupBox {
        VStack(spacing: 15) {
          HStack {
            Button {
              loadImage()
            } label: {
              LongText(title: "Load image")
            }
            Button {
              showImageCropper.toggle()
            } label: {
              LongText(title: "Crop image")
            }
          }
          
          HStack {
            Text("Mask shape")
              .frame(maxWidth: .infinity, alignment: .leading)
            
            Picker("maskShape", selection: $selectedShape.animation()) {
              ForEach(MaskShape.allCases, id: \.self) { mask in
                Text(String(describing: mask))
              }
            }
            .pickerStyle(.segmented)
          }
          
          if selectedShape == .rectangle {
            HStack {
              Text("Rect aspect ratio")
                .frame(maxWidth: .infinity, alignment: .leading)
              
              Picker("rectAspectRatio", selection: $rectAspectRatio) {
                ForEach(PresetAspectRatios.allCases, id: \.self) { aspectRatio in
                  Text(aspectRatio.rawValue)
                }
                
              }
              .pickerStyle(.segmented)
            }

            Toggle("Allow aspect ratio resizing", isOn: $allowAspectRatioResizing)

            if allowAspectRatioResizing {
              HStack {
                Text("Min aspect ratio")
                  .frame(maxWidth: .infinity, alignment: .leading)
                DecimalTextField(value: $minAspectRatio)
                  .focused($textFieldFocused)
              }
              HStack {
                Text("Max aspect ratio")
                  .frame(maxWidth: .infinity, alignment: .leading)
                DecimalTextField(value: $maxAspectRatio)
                  .focused($textFieldFocused)
              }
            }
          }

          Toggle("Crop image to circle", isOn: $cropImageCircular)
          
          Toggle("Rotate image (gestures)", isOn: $rotateImage)
          
          Toggle("Rotate image (buttons)", isOn: $rotateImageWithButtons)
          
          HStack {
            Text("Max magnification")
              .frame(maxWidth: .infinity, alignment: .leading)
            
            DecimalTextField(value: $maxMagnificationScale)
              .focused($textFieldFocused)
          }
          
          HStack {
            Text("Mask radius")
              .frame(maxWidth: .infinity, alignment: .leading)

            #if os(iOS)
            Button {
              maskRadius = min(UIScreen.main.bounds.width, UIScreen.main.bounds.height) / 2
            } label: {
              Image(systemName: "arrow.up.left.and.arrow.down.right")
                .font(.footnote)
            }
            #elseif os(macOS)
            Button {
              if let screen = NSScreen.main {
                maskRadius = min(screen.frame.width, screen.frame.height) / 2
              } else {
                maskRadius = 200
              }
            } label: {
              Image(systemName: "arrow.up.left.and.arrow.down.right")
                .font(.footnote)
            }
            #endif

            DecimalTextField(value: $maskRadius)
              .focused($textFieldFocused)
          }
          
          HStack {
            Text("Zoom sensitivity")
            
              .frame(maxWidth: .infinity, alignment: .leading)
            
            DecimalTextField(value: $zoomSensitivity)
              .focused($textFieldFocused)
          }
        }
      }
      .toolbar {
#if os(visionOS)
        ToolbarItemGroup(placement: .bottomOrnament) {
          Button("Done") {
            textFieldFocused = false
          }
        }
#else
        ToolbarItemGroup(placement: .keyboard) {
          Spacer()
          
          Button("Done") {
            textFieldFocused = false
          }
        }
#endif
      }
      .buttonStyle(.bordered)
      .padding()
    }
    .onAppear {
      loadImage()
    }
    #if os(macOS)
    .frame(minWidth: 600, minHeight: 700)
    .onChange(of: showImageCropper) { isShowing in
      guard isShowing, let image = selectedImage else { return }
      cropSession.image = image
      cropSession.maskShape = selectedShape
      cropSession.configuration = makeCropConfiguration()
      cropSession.onComplete = { croppedImage in
        self.selectedImage = croppedImage
      }
      cropSession.onCancel = nil
      openWindow(id: "crop-image")
      showImageCropper = false
    }
    #else
    .fullScreenCover(isPresented: $showImageCropper) {
      imageCropperView
    }
    #endif
  }

  @ViewBuilder
  private var imageCropperView: some View {
    if let selectedImage = selectedImage {
      SwiftyCropView(
        imageToCrop: selectedImage,
        maskShape: selectedShape,
        configuration: makeCropConfiguration(),
        onCancel: {
          print("Operation cancelled")
        }
      ) { croppedImage in
        // Do something with the returned, cropped image
        self.selectedImage = croppedImage
      }
    }
  }

  private func makeCropConfiguration() -> SwiftyCropConfiguration {
    SwiftyCropConfiguration(
      maxMagnificationScale: maxMagnificationScale,
      maskRadius: maskRadius,
      cropImageCircular: cropImageCircular,
      rotateImage: rotateImage,
      rotateImageWithButtons: rotateImageWithButtons,
      zoomSensitivity: zoomSensitivity,
      rectAspectRatio: rectAspectRatio.getValue(),
      allowAspectRatioResizing: allowAspectRatioResizing,
      minAspectRatio: minAspectRatio,
      maxAspectRatio: maxAspectRatio,
      colors: SwiftyCropConfiguration.Colors(
        cancelButton: Color.primary,
        interactionInstructions: Color.primary,
        rotateButton: Color.primary,
        resetRotationButton: Color.primary,
        saveButton: Color.primary,
        background: Color.primary,
        cropHandle: Color.primary
      )
    )
  }

  private func loadImage() {
    Task {
      selectedImage = await downloadExampleImage()
    }
  }
  
  // Example function for downloading an image
  private func downloadExampleImage() async -> PlatformImage? {
    let portraitUrlString = "https://picsum.photos/1000/1200"
    let landscapeUrlString = "https://picsum.photos/2000/1000"
    let urlString = Int.random(in: 0...1) == 0 ? portraitUrlString : landscapeUrlString
    guard let url = URL(string: urlString),
          let (data, _) = try? await URLSession.shared.data(from: url),
          let image = PlatformImage(data: data)
    else { return nil }

    return image
  }
}

struct DemoPlatformImageView: View {
  let image: PlatformImage

  var body: some View {
    #if canImport(UIKit)
    Image(uiImage: image)
      .resizable()
    #elseif canImport(AppKit)
    Image(nsImage: image)
      .resizable()
    #endif
  }
}

#Preview {
  ContentView()
}
