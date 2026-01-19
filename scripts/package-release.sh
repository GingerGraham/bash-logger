#!/usr/bin/env bash
#
# package-release.sh - Create consumer-friendly release packages
#
# This script packages only the files consumers need:
# - logging.sh (main module)
# - configuration/ (example configs)
# - demo-scripts/ (usage examples)
# - docs/ (user-facing documentation only)
#
# Usage: ./scripts/package-release.sh VERSION
# Example: ./scripts/package-release.sh 0.10.0

set -e

VERSION="${1:-}"
if [[ -z "$VERSION" ]]; then
    echo "Error: Version required"
    echo "Usage: $0 VERSION"
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PACKAGE_DIR="$PROJECT_ROOT/release-package"
PACKAGE_NAME="bash-logger-${VERSION}"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Creating Release Package: $PACKAGE_NAME"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Clean any existing package directory
if [[ -d "$PACKAGE_DIR" ]]; then
    echo "Cleaning existing package directory..."
    rm -rf "$PACKAGE_DIR"
fi

# Create package structure
mkdir -p "$PACKAGE_DIR/$PACKAGE_NAME"

echo "Copying consumer files..."

# Copy main module
cp "$PROJECT_ROOT/logging.sh" "$PACKAGE_DIR/$PACKAGE_NAME/"

# Also copy logging.sh to the root of release-package for standalone distribution
cp "$PROJECT_ROOT/logging.sh" "$PACKAGE_DIR/"

# Copy directories
cp -r "$PROJECT_ROOT/configuration" "$PACKAGE_DIR/$PACKAGE_NAME/"
cp -r "$PROJECT_ROOT/demo-scripts" "$PACKAGE_DIR/$PACKAGE_NAME/"

# Copy documentation (excluding repo-specific docs)
mkdir -p "$PACKAGE_DIR/$PACKAGE_NAME/docs"
for doc in "$PROJECT_ROOT/docs"/*.md; do
    filename=$(basename "$doc")
    # Exclude repo-operation docs
    case "$filename" in
        PRE-COMMIT.md|testing.md|releases.md)
            echo "  Excluding: docs/$filename (repo-specific)"
            ;;
        *)
            echo "  Including: docs/$filename"
            cp "$doc" "$PACKAGE_DIR/$PACKAGE_NAME/docs/"
            ;;
    esac
done

# Copy essential project files
echo "Copying project files..."
cp "$PROJECT_ROOT/README.md" "$PACKAGE_DIR/$PACKAGE_NAME/"
cp "$PROJECT_ROOT/LICENSE" "$PACKAGE_DIR/$PACKAGE_NAME/"
cp "$PROJECT_ROOT/CHANGELOG.md" "$PACKAGE_DIR/$PACKAGE_NAME/"

# Create a consumer-focused README for the package
cat > "$PACKAGE_DIR/$PACKAGE_NAME/INSTALL.md" << 'EOF'
# Installation Guide

Thank you for downloading bash-logger!

## Quick Start

1. **Source the module** in your script:

   ```bash
   source logging.sh
   ```

2. **Initialize the logger**:

   ```bash
   init_logger --level INFO
   ```

3. **Start logging**:

   ```bash
   log_info "Application started"
   log_warn "This is a warning"
   log_error "Something went wrong"
   ```

## What's Included

- `logging.sh` - The main logging module
- `configuration/` - Example configuration files
- `demo-scripts/` - Working examples demonstrating features
- `docs/` - Complete documentation
- `README.md` - Project overview
- `CHANGELOG.md` - Version history
- `LICENSE` - MIT License

## Documentation

Start with these docs:

- `docs/getting-started.md` - Basic usage and examples
- `docs/initialization.md` - Configuration options
- `docs/log-levels.md` - Understanding log levels
- `README.md` - Project overview and features

## Running Examples

Try the demo scripts to see features in action:

```bash
cd demo-scripts
./run_demos.sh
```

Or run individual demos:

```bash
./demo-scripts/demo_log_levels.sh
./demo-scripts/demo_colors.sh
./demo-scripts/demo_config.sh
```

## Installation Options

### Option 1: Copy to Your Project

```bash
cp logging.sh /path/to/your/project/
```

### Option 2: Install System-Wide

```bash
sudo cp logging.sh /usr/local/lib/
# Then source it: source /usr/local/lib/logging.sh
```

### Option 3: Use from Current Location

```bash
# Add to your script's directory and source relatively
source "$(dirname "$0")/logging.sh"
```

## Support

- **Issues**: https://github.com/GingerGraham/bash-logger/issues
- **Documentation**: See the `docs/` directory
- **Examples**: See the `demo-scripts/` directory

## License

MIT License - See LICENSE file for details
EOF

echo ""
echo "Creating archives..."

# Create tarball
cd "$PACKAGE_DIR"
tar -czf "${PACKAGE_NAME}.tar.gz" "$PACKAGE_NAME"
echo "✓ Created: ${PACKAGE_NAME}.tar.gz"

# Create zip
zip -q -r "${PACKAGE_NAME}.zip" "$PACKAGE_NAME"
echo "✓ Created: ${PACKAGE_NAME}.zip"

# Generate checksums for packages
sha256sum "${PACKAGE_NAME}.tar.gz" > "${PACKAGE_NAME}.tar.gz.sha256"
sha256sum "${PACKAGE_NAME}.zip" > "${PACKAGE_NAME}.zip.sha256"
echo "✓ Created: package checksums"

# Generate checksum for standalone logging.sh
sha256sum "logging.sh" > "logging.sh.sha256"
echo "✓ Created: logging.sh checksum"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Package Complete"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Standalone module:"
echo "  - logging.sh ($(du -h "logging.sh" | cut -f1))"
echo ""
echo "Package archives:"
echo "  - ${PACKAGE_NAME}.tar.gz ($(du -h "${PACKAGE_NAME}.tar.gz" | cut -f1))"
echo "  - ${PACKAGE_NAME}.zip ($(du -h "${PACKAGE_NAME}.zip" | cut -f1))"
echo ""
echo "Package contents:"
find "$PACKAGE_NAME" -type f | wc -l | xargs echo "  Files:"
du -sh "$PACKAGE_NAME" | cut -f1 | xargs echo "  Total size:"
echo ""
echo "Location: $PACKAGE_DIR"
echo ""
