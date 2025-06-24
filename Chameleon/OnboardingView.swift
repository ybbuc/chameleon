//
//  OnboardingView.swift
//  Chameleon
//
//  Created by Jakob Wells on 23.06.25.
//

import SwiftUI
import AppKit

struct OnboardingView: View {
    @Binding var showOnboarding: Bool
    @State private var currentStep = 0
    @State private var homebrewInstalled = false
    @State private var pandocInstalled = false
    @State private var imagemagickInstalled = false
    @State private var latexInstalled = false
    @State private var isCheckingDependencies = true
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 16) {
                Text("Welcome to Chameleon")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("Let's set up your file conversion tools.")
                    .font(.title3)
                    .foregroundColor(.secondary)
            }
            .padding(.top, 40)
            .padding(.bottom, 30)
            
            // Progress indicator
            HStack(spacing: 8) {
                ForEach(0..<4) { index in
                    Circle()
                        .fill(index <= currentStep ? Color.accentColor : Color.gray.opacity(0.3))
                        .frame(width: 4, height: 4)
                }
            }
            .padding(.bottom, 20)
            
            // Content
            Group {
                switch currentStep {
                case 0:
                    WelcomeStep()
                case 1:
                    HomebrewStep(isInstalled: $homebrewInstalled)
                case 2:
                    DependenciesStep(
                        pandocInstalled: $pandocInstalled,
                        imagemagickInstalled: $imagemagickInstalled,
                        latexInstalled: $latexInstalled
                    )
                case 3:
                    CompletionStep()
                default:
                    EmptyView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, 40)
            
            // Navigation
            HStack {
                if currentStep > 0 {
                    Button("Back") {
                        withAnimation {
                            currentStep -= 1
                        }
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if currentStep < 3 {
                    Button("Skip Setup") {
                        showOnboarding = false
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.secondary)
                    
                    Button(currentStep == 0 ? "Get Started" : "Continue") {
                        withAnimation {
                            currentStep += 1
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(currentStep == 1 && !homebrewInstalled)
                } else {
                    Button("Start Using Chameleon") {
                        showOnboarding = false
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
            }
            .padding(30)
        }
        .frame(width: 750, height: 700)
        .background(Color(NSColor.windowBackgroundColor))
        .onAppear {
            checkDependencies()
        }
    }
    
    private func checkDependencies() {
        isCheckingDependencies = true
        
        DispatchQueue.global(qos: .userInitiated).async {
            // Check Homebrew - try multiple paths where brew might be installed
            let homebrewPaths = ["/opt/homebrew/bin/brew", "/usr/local/bin/brew"]
            var homebrewFound = false
            
            for path in homebrewPaths {
                if FileManager.default.fileExists(atPath: path) {
                    homebrewFound = true
                    break
                }
            }
            
            // Also check using command as fallback
            if !homebrewFound {
                let homebrewResult = Process.run(command: "/bin/bash", arguments: ["-c", "command -v brew"])
                homebrewFound = homebrewResult.exitCode == 0 && !homebrewResult.output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }
            
            // Check Pandoc
            let pandocResult = Process.run(command: "/bin/bash", arguments: ["-c", "command -v pandoc"])
            let pandocFound = pandocResult.exitCode == 0 && !pandocResult.output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            
            // Check ImageMagick
            let imagemagickResult = Process.run(command: "/bin/bash", arguments: ["-c", "command -v convert"])
            let imagemagickFound = imagemagickResult.exitCode == 0 && !imagemagickResult.output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            
            // Check LaTeX (optional)
            let latexResult = Process.run(command: "/bin/bash", arguments: ["-c", "command -v pdflatex"])
            let latexFound = latexResult.exitCode == 0 && !latexResult.output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            
            DispatchQueue.main.async {
                self.homebrewInstalled = homebrewFound
                self.pandocInstalled = pandocFound
                self.imagemagickInstalled = imagemagickFound
                self.latexInstalled = latexFound
                self.isCheckingDependencies = false
                
                // Skip to appropriate step if dependencies are already installed
                if homebrewFound && pandocFound && imagemagickFound {
                    self.currentStep = 3
                } else if homebrewFound {
                    self.currentStep = 2
                }
            }
        }
    }
}

struct WelcomeStep: View {
    var body: some View {
        VStack(spacing: 24) {
            Text("Chameleon needs a few tools to convert your documents")
                .font(.headline)
                .multilineTextAlignment(.center)
            
            VStack(alignment: .leading, spacing: 16) {
                FeatureRowWithLink(
                    icon: "doc.text",
                    title: "Pandoc",
                    description: "Universal document converter for text formats",
                    url: "https://pandoc.org"
                )
                
                FeatureRowWithLink(
                    icon: "photo",
                    title: "ImageMagick",
                    description: "Powerful image conversion and manipulation",
                    url: "https://imagemagick.org"
                )
                
                FeatureRowWithLink(
                    icon: "doc.richtext",
                    title: "LaTeX (Optional)",
                    description: "Professional PDF generation with MacTeX",
                    url: "https://tug.org/mactex/"
                )
            }
            .padding(.vertical, 20)
            
            Text("We'll guide you through installing these tools")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
}

struct HomebrewStep: View {
    @Binding var isInstalled: Bool
    @State private var isChecking = false
    @State private var showCopyConfirmation = false
    
    let installCommand = "/bin/bash -c \"$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
    
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: isInstalled ? "checkmark.circle.fill" : "shippingbox")
                .font(.system(size: 48))
                .foregroundStyle(isInstalled ? .green : .accentColor)
            
            Text(isInstalled ? "Homebrew is installed!" : "Install Homebrew")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text(isInstalled ? 
                 "Great! Homebrew is already installed on your system." :
                 "Homebrew is a package manager that makes it easy to install command-line tools on macOS.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            
            if !isInstalled {
                VStack(spacing: 16) {
                    Text("Copy and run this command in Terminal:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    HStack {
                        Text(installCommand)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(.primary)
                            .lineLimit(2)
                            .truncationMode(.middle)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        Button {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(installCommand, forType: .string)
                            showCopyConfirmation = true
                            
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                showCopyConfirmation = false
                            }
                        } label: {
                            Image(systemName: showCopyConfirmation ? "checkmark" : "doc.on.doc")
                                .foregroundColor(showCopyConfirmation ? .green : .accentColor)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    
                    Button("Open Terminal") {
                        NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Utilities/Terminal.app"))
                    }
                    .buttonStyle(.bordered)
                }
            }
            
            Spacer()
            
            Button(isInstalled ? "Verify Installation" : "Check Again") {
                checkHomebrew()
            }
            .buttonStyle(.bordered)
            .disabled(isChecking)
        }
    }
    
    private func checkHomebrew() {
        isChecking = true
        DispatchQueue.global(qos: .userInitiated).async {
            // Check common Homebrew installation paths
            let homebrewPaths = ["/opt/homebrew/bin/brew", "/usr/local/bin/brew"]
            var homebrewFound = false
            
            for path in homebrewPaths {
                if FileManager.default.fileExists(atPath: path) {
                    homebrewFound = true
                    break
                }
            }
            
            // Also check using command -v as fallback
            if !homebrewFound {
                let result = Process.run(command: "/bin/bash", arguments: ["-c", "command -v brew"])
                homebrewFound = result.exitCode == 0 && !result.output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }
            
            DispatchQueue.main.async {
                withAnimation {
                    isInstalled = homebrewFound
                }
                isChecking = false
            }
        }
    }
}

struct DependenciesStep: View {
    @Binding var pandocInstalled: Bool
    @Binding var imagemagickInstalled: Bool
    @Binding var latexInstalled: Bool
    @State private var isInstalling = false
    @State private var currentInstall: String?
    
    var allRequiredInstalled: Bool {
        pandocInstalled && imagemagickInstalled
    }
    
    var body: some View {
        VStack(spacing: 24) {
            Text("Install Dependencies")
                .font(.title2)
                .fontWeight(.semibold)
            
            VStack(spacing: 12) {
                DependencyRow(
                    name: "Pandoc",
                    command: "brew install pandoc",
                    isInstalled: pandocInstalled,
                    isRequired: true,
                    onInstall: { installDependency("pandoc", command: "brew install pandoc") }
                )
                
                DependencyRow(
                    name: "ImageMagick",
                    command: "brew install imagemagick",
                    isInstalled: imagemagickInstalled,
                    isRequired: true,
                    onInstall: { installDependency("imagemagick", command: "brew install imagemagick") }
                )
                
                DependencyRow(
                    name: "LaTeX (MacTeX)",
                    command: "brew install --cask mactex-no-gui",
                    isInstalled: latexInstalled,
                    isRequired: false,
                    onInstall: { installDependency("mactex-no-gui", command: "brew install --cask mactex-no-gui") }
                )
            }
            
            if !allRequiredInstalled {
                Button("Install All Required") {
                    installAllRequired()
                }
                .buttonStyle(.borderedProminent)
                .disabled(isInstalling)
            }
            
            Spacer()
            
            if allRequiredInstalled {
                Label("All required dependencies are installed!", systemImage: "checkmark.circle.fill")
                    .foregroundColor(.green)
            }
        }
        .onAppear {
            checkAllDependencies()
        }
    }
    
    private func installDependency(_ name: String, command: String) {
        isInstalling = true
        currentInstall = name
        
        DispatchQueue.global(qos: .userInitiated).async {
            let result = Process.run(command: "/bin/bash", arguments: ["-c", command])
            
            DispatchQueue.main.async {
                if result.exitCode == 0 {
                    checkAllDependencies()
                }
                isInstalling = false
                currentInstall = nil
            }
        }
    }
    
    private func installAllRequired() {
        var commands: [String] = []
        
        if !pandocInstalled {
            commands.append("brew install pandoc")
        }
        if !imagemagickInstalled {
            commands.append("brew install imagemagick")
        }
        
        let combinedCommand = commands.joined(separator: " && ")
        installDependency("all", command: combinedCommand)
    }
    
    private func checkAllDependencies() {
        DispatchQueue.global(qos: .userInitiated).async {
            // Check Pandoc
            let pandocResult = Process.run(command: "/bin/bash", arguments: ["-c", "command -v pandoc"])
            let pandocFound = pandocResult.exitCode == 0 && !pandocResult.output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            
            // Check ImageMagick
            let imagemagickResult = Process.run(command: "/bin/bash", arguments: ["-c", "command -v convert"])
            let imagemagickFound = imagemagickResult.exitCode == 0 && !imagemagickResult.output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            
            // Check LaTeX (optional)
            let latexResult = Process.run(command: "/bin/bash", arguments: ["-c", "command -v pdflatex"])
            let latexFound = latexResult.exitCode == 0 && !latexResult.output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            
            DispatchQueue.main.async {
                withAnimation {
                    pandocInstalled = pandocFound
                    imagemagickInstalled = imagemagickFound
                    latexInstalled = latexFound
                }
            }
        }
    }
}

struct CompletionStep: View {
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(.green)
            
            Text("You're all set!")
                .font(.title)
                .fontWeight(.bold)
            
            Text("Chameleon is ready to convert your documents")
                .font(.title3)
                .foregroundColor(.secondary)
            
            VStack(alignment: .leading, spacing: 16) {
                Label("Drag and drop files to convert", systemImage: "arrow.up.doc")
                Label("Choose from 100+ output formats", systemImage: "doc.badge.arrow.up.right")
                Label("Preview files with Quick Look", systemImage: "eye")
                Label("Access recent conversions anytime", systemImage: "clock.arrow.circlepath")
            }
            .font(.body)
            .padding(.vertical, 20)
            
            Spacer()
        }
    }
}

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(Color.accentColor)
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
    }
}

struct FeatureRowWithLink: View {
    let icon: String
    let title: String
    let description: String
    let url: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(Color.accentColor)
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 4) {
                Button(title) {
                    if let url = URL(string: url) {
                        NSWorkspace.shared.open(url)
                    }
                }
                .buttonStyle(.plain)
                .font(.headline)
                .foregroundColor(.primary)
                .onHover { isHovered in
                    if isHovered {
                        NSCursor.pointingHand.push()
                    } else {
                        NSCursor.pop()
                    }
                }
                
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
    }
}

struct DependencyRow: View {
    let name: String
    let command: String
    let isInstalled: Bool
    let isRequired: Bool
    let onInstall: () -> Void
    @State private var showCopyConfirmation = false
    
    var body: some View {
        HStack {
            Image(systemName: isInstalled ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(isInstalled ? .green : .secondary)
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(name)
                        .font(.headline)
                    if !isRequired {
                        Text("Optional")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.gray.opacity(0.2))
                            .clipShape(Capsule())
                    }
                }
                
                if !isInstalled {
                    Text(command)
                        .font(.caption)
                        .fontDesign(.monospaced)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            if !isInstalled {
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(command, forType: .string)
                    showCopyConfirmation = true
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        showCopyConfirmation = false
                    }
                } label: {
                    Image(systemName: showCopyConfirmation ? "checkmark" : "doc.on.doc")
                        .foregroundColor(showCopyConfirmation ? .green : .accentColor)
                }
                .buttonStyle(.plain)
                .help("Copy command")
                
                Button("Install") {
                    onInstall()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// Process helper extension
extension Process {
    struct ProcessResult {
        let output: String
        let error: String
        let exitCode: Int32
    }
    
    static func run(command: String, arguments: [String]) -> ProcessResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: command)
        process.arguments = arguments
        
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        
        // Set environment to include common paths
        var environment = ProcessInfo.processInfo.environment
        let paths = [
            "/opt/homebrew/bin",
            "/usr/local/bin",
            "/usr/bin",
            "/bin",
            "/Library/TeX/texbin"
        ]
        let currentPath = environment["PATH"] ?? ""
        environment["PATH"] = (paths + [currentPath]).joined(separator: ":")
        process.environment = environment
        
        do {
            try process.run()
            process.waitUntilExit()
            
            let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            
            let output = String(data: outputData, encoding: .utf8) ?? ""
            let error = String(data: errorData, encoding: .utf8) ?? ""
            
            return ProcessResult(output: output, error: error, exitCode: process.terminationStatus)
        } catch {
            return ProcessResult(output: "", error: error.localizedDescription, exitCode: -1)
        }
    }
}

#Preview {
    OnboardingView(showOnboarding: .constant(true))
}
