#!/bin/bash

# ClawLaw Build and Test Script

set -e  # Exit on error

echo "⚖️  ClawLaw Build System"
echo "═══════════════════════════════════════"
echo ""

# Check if Swift is installed
if ! command -v swift &> /dev/null; then
    echo "❌ Swift not found. Please install Swift toolchain."
    echo "   Visit: https://swift.org/download/"
    exit 1
fi

SWIFT_VERSION=$(swift --version | head -n 1)
echo "Swift version: $SWIFT_VERSION"
echo ""

# Parse command line arguments
COMMAND=${1:-build}

case $COMMAND in
    build)
        echo "Building ClawLaw..."
        swift build
        echo "✅ Build complete"
        ;;
        
    test)
        echo "Running tests..."
        swift test
        echo "✅ Tests complete"
        ;;
        
    demo)
        echo "Building and running demo..."
        swift run clawlaw demo
        ;;
        
    experiments)
        echo "Running the five experiments..."
        swift run clawlaw test
        ;;
        
    clean)
        echo "Cleaning build artifacts..."
        swift package clean
        rm -rf .build
        echo "✅ Clean complete"
        ;;
        
    release)
        echo "Building release configuration..."
        swift build -c release
        echo "✅ Release build complete"
        echo ""
        echo "Binary location: .build/release/clawlaw"
        ;;
        
    install)
        echo "Installing ClawLaw..."
        swift build -c release
        INSTALL_PATH=/usr/local/bin/clawlaw
        sudo cp .build/release/clawlaw $INSTALL_PATH
        echo "✅ Installed to $INSTALL_PATH"
        ;;
        
    help|--help|-h)
        echo "Usage: ./build.sh [command]"
        echo ""
        echo "Commands:"
        echo "  build        Build the project (default)"
        echo "  test         Run all tests"
        echo "  demo         Run interactive demo"
        echo "  experiments  Run the five governance experiments"
        echo "  clean        Clean build artifacts"
        echo "  release      Build release configuration"
        echo "  install      Install to /usr/local/bin"
        echo "  help         Show this help"
        echo ""
        ;;
        
    *)
        echo "❌ Unknown command: $COMMAND"
        echo "Run './build.sh help' for usage"
        exit 1
        ;;
esac

echo ""
echo "═══════════════════════════════════════"
