<div align="center">

![Chameleon icon](./Chameleon/Assets.xcassets/AppIcon.appiconset/AppIcon_0256.png)

# Chameleon

A native macOS desktop application for universal file conversion, supporting document, image, video, and audio formats. Built with Swift and SwiftUI, it provides a drag-and-drop interface for converting between 100+ file formats.
</div>

## Requirements

- macOS 14.0+
- Xcode 16.4+
- External dependencies (all optional - features auto-disable if not installed):
  - **Pandoc** (for document formats): `brew install pandoc`
  - **ImageMagick** (for image formats): `brew install imagemagick`
  - **LaTeX** (for enhanced PDF support): `brew install --cask basictex`
  - **Ghostscript** (for enhanced PDF support): `brew install ghostscript`

## Setup

1. Clone the repository
2. Install dependencies (install only the formats you need):
   ```bash
   # For document conversion (Markdown, HTML, DOCX, etc.)
   brew install pandoc
   
   # For image conversion (JPEG, PNG, GIF, etc.)
   brew install imagemagick
   
   # Optional for enhanced PDF support
   brew install --cask basictex
   brew install ghostscript
   ```
3. Open `Chameleon.xcodeproj` in Xcode
4. Build and run (⌘R)

> **Note**: Chameleon will automatically detect which tools are installed and only show supported formats. You can run the app with any combination of the above dependencies.

## Project Structure

```
Chameleon/
├── Models/          # Data models, format configs, conversion options
├── Services/        # Conversion wrappers and business logic
├── Views/           # SwiftUI views
│   ├── Components/  # Reusable UI components
│   ├── FileViews/   # File state-specific views
│   ├── Main/        # Main app views (ConverterView, HistoryView)
│   └── Options/     # Format-specific option views
└── Assets.xcassets/ # App resources and sounds
```

## Features

- **Universal File Conversion**: Support for 100+ file formats across documents, images, audio, and video
- **Smart Dependency Detection**: Automatically detects installed tools and disables unsupported formats
- **Document Conversion**: Markdown, HTML, DOCX, LaTeX, PDF, RTF, EPUB, and more via Pandoc
- **Image Conversion**: JPEG, PNG, GIF, WebP, TIFF, and more via ImageMagick
- **Audio/Video Conversion**: MP4, MP3, AVI, MOV, and more via FFmpeg
- **Archive Support**: ZIP, TAR, and other archive formats with compression levels
- **OCR Text Extraction**: Extract text from images using Vision framework
- **PDF Processing**: Native PDF to image conversion using Apple's PDFKit
- **Drag-and-Drop Interface**: Intuitive file handling with visual feedback
- **Quick Look Preview**: Preview converted files before saving
- **Conversion History**: Track and quickly access recent saved conversions
- **Format-Specific Options**: Quality settings, compression levels, and advanced parameters
- **Native SwiftUI Design**: Modern macOS interface with responsive UI
- **Batch Processing**: Convert multiple files at once

## Dependency Behavior

The app will run with any combination of tools installed—only the supported formats will be available in the interface.
