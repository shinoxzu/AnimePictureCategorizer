import SwiftUI

struct ContentView: View {
    @State private var model: AnimePictureCategorizerModel?
    
    @State private var isInputDirectoryPickerPresented = false
    @State private var isOutputDirectoryPickerPresented = false
    
    @State private var inputDirectory: URL?
    @State private var outputDirectory: URL?
    
    @State private var isLoading = false
    @State private var showCompletionAlert = false
    @State private var errorMessage: String?
    
    private let allowedExtensions: Set<String> = [
        "jpg", "jpeg", "png", "gif", "bmp", "tiff", "heic", "webp",
    ]
    
    var body: some View {
        VStack(spacing: 20) {
            VStack(spacing: 12) {
                DirectoryButton(
                    title: "Select Input Directory",
                    systemImage: "square.and.arrow.down",
                    isSelected: inputDirectory != nil
                ) {
                    isInputDirectoryPickerPresented = true
                }
                .fileImporter(
                    isPresented: $isInputDirectoryPickerPresented,
                    allowedContentTypes: [.directory],
                    onCompletion: selectInputDirectory
                )
                
                DirectoryButton(
                    title: "Select Output Directory",
                    systemImage: "square.and.arrow.up",
                    isSelected: outputDirectory != nil
                ) {
                    isOutputDirectoryPickerPresented = true
                }
                .fileImporter(
                    isPresented: $isOutputDirectoryPickerPresented,
                    allowedContentTypes: [.directory],
                    onCompletion: selectOutputDirectory
                )
            }
            
            Button(action: proceed) {
                HStack {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(
                                CircularProgressViewStyle(tint: .white)
                            )
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "play.circle.fill")
                            .font(.title2)
                    }
                    Text(isLoading ? "Processing..." : "Start Processing")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            .disabled(
                inputDirectory == nil
                || outputDirectory == nil
                || model == nil
                || isLoading)
        }
        .padding()
        .frame(maxWidth: 400)
        .animation(.easeInOut(duration: 0.2), value: isLoading)
        .animation(.easeInOut(duration: 0.2), value: inputDirectory)
        .animation(.easeInOut(duration: 0.2), value: outputDirectory)
        .alert("Completed", isPresented: $showCompletionAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("All files have been processed")
        }
        .alert(
            "Error",
            isPresented: .init(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            if let errorMessage {
                Text(errorMessage)
            }
        }
        .task {
            DispatchQueue.global().async {
                model = try? AnimePictureCategorizerModel()
            }
        }
    }
    
    func selectInputDirectory(_ dir: Result<URL, any Error>) {
        switch dir {
        case .success(let url):
            inputDirectory = url
        case .failure(let error):
            errorMessage =
            "Failed to select input directory: \(error.localizedDescription)"
        }
        
        isInputDirectoryPickerPresented = false
    }
    
    func selectOutputDirectory(_ dir: Result<URL, any Error>) {
        switch dir {
        case .success(let url):
            outputDirectory = url
        case .failure(let error):
            errorMessage = "Failed to select output directory: \(error.localizedDescription)"
        }
        
        isOutputDirectoryPickerPresented = false
    }
    
    func proceed() {
        guard let inputDirectory, let outputDirectory else { return }
        guard let model else { return }
        
        isLoading = true
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                guard inputDirectory.startAccessingSecurityScopedResource()
                else {
                    DispatchQueue.main.async {
                        isLoading = false
                        errorMessage = "Cannot access input directory"
                    }
                    return;
                }
                defer { inputDirectory.stopAccessingSecurityScopedResource() }
                
                guard outputDirectory.startAccessingSecurityScopedResource()
                else {
                    DispatchQueue.main.async {
                        isLoading = false
                        errorMessage = "Cannot access output directory"
                    }
                    return;
                }
                defer { outputDirectory.stopAccessingSecurityScopedResource() }
                
                try createOutputDirectories(baseDirectory: outputDirectory)
                
                guard
                    let filesToPredict = FileManager.default.enumerator(
                        at: inputDirectory, includingPropertiesForKeys: nil
                    )
                else {
                    DispatchQueue.main.async {
                        isLoading = false
                        errorMessage = "Cannot enumerate files"
                    }
                    return;
                }
                
                var files: [URL] = []
                var modelInputs: [AnimePictureCategorizerModelInput] = []
                
                for case let file as URL in filesToPredict {
                    if allowedExtensions.contains(file.pathExtension.lowercased()) {
                        do {
                            let input = try AnimePictureCategorizerModelInput(imageAt: file)
                            files.append(file)
                            modelInputs.append(input)
                        } catch {
                            print("Failed to create model input for file: \(file.path). Error: \(error)")
                            continue
                        }
                    }
                }
                
                if files.isEmpty {
                    DispatchQueue.main.async {
                        isLoading = false
                        errorMessage = "No valid files found"
                    }
                    return;
                }
                
                let predictions = try model.predictions(inputs: modelInputs)
                
                for (prediction, file) in zip(predictions, files) {
                    let targetDirectory = outputDirectory.appendingPathComponent(prediction.target)
                    let destination = targetDirectory.appendingPathComponent(file.lastPathComponent)
                    
                    do {
                        try FileManager.default.moveItem(at: file, to: destination)
                    } catch {
                        print("Failed to move file: \(file.path). Error: \(error)")
                    }
                }
                
                DispatchQueue.main.async {
                    isLoading = false
                    showCompletionAlert = true
                }
            } catch {
                DispatchQueue.main.async {
                    isLoading = false
                    errorMessage = "Error during processing: \(error)"
                }
            }
        }
    }
    
    func createOutputDirectories(baseDirectory: URL) throws {
        let sfwPath = baseDirectory.appendingPathComponent("sfw")
        let nsfwPath = baseDirectory.appendingPathComponent("nsfw")
        
        if !FileManager.default.fileExists(atPath: sfwPath.path()) {
            try FileManager.default.createDirectory(
                at: sfwPath,
                withIntermediateDirectories: true
            )
        }
        
        if !FileManager.default.fileExists(atPath: nsfwPath.path()) {
            try FileManager.default.createDirectory(
                at: nsfwPath,
                withIntermediateDirectories: true
            )
        }
    }
}

#Preview {
    ContentView()
}
