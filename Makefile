# FanzyZones — build the SwiftPM executable and assemble a runnable .app bundle.

APP_NAME    := FanzyZones
BUNDLE_ID   := com.fanzyzones.app
VERSION     := 0.1.3
CONFIG      := release

BUILD_DIR   := .build/$(CONFIG)
APP_BUNDLE  := $(APP_NAME).app
CONTENTS    := $(APP_BUNDLE)/Contents
MACOS_DIR   := $(CONTENTS)/MacOS
RES_DIR     := $(CONTENTS)/Resources
ICONSET     := .build/AppIcon.iconset
ICNS        := .build/AppIcon.icns

.PHONY: all build app sign run clean test icon

all: app

build:
	swift build -c $(CONFIG)

# Render the app icon and convert it to .icns (rebuilt only if missing).
icon:
	@if [ ! -f "$(ICNS)" ]; then \
		swift scripts/make-icon.swift "$(ICONSET)" && \
		iconutil -c icns "$(ICONSET)" -o "$(ICNS)"; \
	fi

# Assemble FanzyZones.app around the built executable, then codesign it.
app: build icon
	@rm -rf "$(APP_BUNDLE)"
	@mkdir -p "$(MACOS_DIR)" "$(RES_DIR)"
	@cp "$(BUILD_DIR)/$(APP_NAME)" "$(MACOS_DIR)/$(APP_NAME)"
	@cp "$(ICNS)" "$(RES_DIR)/AppIcon.icns"
	@printf '%s\n' \
		'<?xml version="1.0" encoding="UTF-8"?>' \
		'<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">' \
		'<plist version="1.0">' \
		'<dict>' \
		'  <key>CFBundleName</key><string>$(APP_NAME)</string>' \
		'  <key>CFBundleDisplayName</key><string>$(APP_NAME)</string>' \
		'  <key>CFBundleIdentifier</key><string>$(BUNDLE_ID)</string>' \
		'  <key>CFBundleVersion</key><string>$(VERSION)</string>' \
		'  <key>CFBundleShortVersionString</key><string>$(VERSION)</string>' \
		'  <key>CFBundleExecutable</key><string>$(APP_NAME)</string>' \
		'  <key>CFBundleIconFile</key><string>AppIcon</string>' \
		'  <key>CFBundlePackageType</key><string>APPL</string>' \
		'  <key>LSMinimumSystemVersion</key><string>14.0</string>' \
		'  <key>LSUIElement</key><true/>' \
		'  <key>NSPrincipalClass</key><string>NSApplication</string>' \
		'  <key>NSHighResolutionCapable</key><true/>' \
		'</dict>' \
		'</plist>' > "$(CONTENTS)/Info.plist"
	@$(MAKE) sign
	@echo "Built $(APP_BUNDLE)"

# Sign with the stable self-signed identity if present (so macOS keeps the
# Accessibility grant across rebuilds); otherwise fall back to ad-hoc.
# Create the identity once with: ./scripts/make-signing-cert.sh
SIGN_IDENTITY ?= FanzyZones Dev
sign:
	@if security find-identity -v -p codesigning | grep -q "$(SIGN_IDENTITY)"; then \
		echo "Signing with '$(SIGN_IDENTITY)'"; \
		codesign --force --deep --sign "$(SIGN_IDENTITY)" --timestamp=none "$(APP_BUNDLE)"; \
	else \
		echo "Signing ad-hoc (run scripts/make-signing-cert.sh for a stable identity)"; \
		codesign --force --deep --sign - "$(APP_BUNDLE)"; \
	fi

run: app
	open "./$(APP_BUNDLE)"

test:
	swift test

clean:
	rm -rf .build "$(APP_BUNDLE)"
