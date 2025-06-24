# Chameleon

A macOS application with integrated pandoc and ImageMagick support for document and image conversion.

## Requirements

- macOS 14.0+
- Xcode 16.4+
- Pandoc (required): `brew install pandoc`
- ImageMagick (required): `brew install imagemagick`
- LaTeX (optional, for PDF export): `brew install --cask mactex-no-gui`

## Setup

1. Clone the repository
2. Install dependencies:
   ```bash
   # Install pandoc (required)
   brew install pandoc
   
   # Install ImageMagick (required)
   brew install imagemagick
   
   # Install LaTeX for PDF support (optional)
   brew install --cask mactex-no-gui
   ```
3. Open `Chameleon.xcodeproj` in Xcode
4. Build and run

## Project Structure

- `Chameleon/` - Main application source code
- `ChameleonTests/` - Unit tests
- `ChameleonUITests/` - UI tests

## Features

- **Guided Setup** - Interactive onboarding walks you through installing dependencies
- Document conversion between multiple formats
- Image conversion with ImageMagick integration
- Drag-and-drop interface
- Quick Look preview for converted files before saving
- Recent conversions history with quick access
- Native SwiftUI design
- Supports: Markdown, HTML, DOCX, LaTeX, PDF (with LaTeX), RTF, EPUB, image formats (JPEG, PNG, TIFF, etc.), and more
