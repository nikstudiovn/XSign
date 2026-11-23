NAME := XSign
SCHEME := XSign
PLATFORMS := iphoneos

TMP := $(TMPDIR)/$(NAME)

# Optional SSL pack (same JSON format as the former backloop.dev pack.json) used only by
# the "Fully Local" server mode. backloop.dev was discontinued, so this is empty by default
# and XSign installs through Semi Local mode. Example:
#   make CERT_JSON_URL=https://example.com/pack.json
CERT_JSON_URL ?=

.PHONY: all clean deps $(PLATFORMS)

all: $(PLATFORMS)

clean:
	rm -rf $(TMP)
	rm -rf packages
	rm -rf Payload

deps:
	rm -rf deps || true
	mkdir -p deps

	@if [ -n "$(CERT_JSON_URL)" ]; then \
		curl -fsSL "$(CERT_JSON_URL)" -o cert.json && \
		jq -r '.cert' cert.json > deps/server.crt && \
		jq -r '.key1, .key2' cert.json > deps/server.pem && \
		jq -r '.info.domains.commonName' cert.json > deps/commonName.txt; \
	else \
		echo "CERT_JSON_URL not set, skipping SSL pack (Semi Local mode only)"; \
	fi


$(PLATFORMS): deps
	rm -rf _build

	@if [ "$@" = "iphoneos" ]; then \
		DEST="generic/platform=iOS"; \
	else \
		DEST="generic/platform=macOS,variant=Mac Catalyst"; \
	fi; \
	xcodebuild \
		-project XSign.xcodeproj \
		-scheme $(SCHEME) \
		-configuration Release \
		-destination "$$DEST" \
		-derivedDataPath $(TMP)/$@ \
		-skipPackagePluginValidation \
		CODE_SIGNING_ALLOWED=NO \
		ALWAYS_EMBED_SWIFT_STANDARD_LIBRARIES=NO

	mkdir -p _build/Payload
	cp -R _build/Applications/*.app _build/Payload/XSign.app
	chmod -R 0755 _build/Payload/XSign.app
	codesign --force --deep --sign - --timestamp=none _build/Payload/XSign.app
	cp deps/* _build/Payload/XSign.app/ 2>/dev/null || true

	mkdir -p packages

	@if [ "$@" = "iphoneos" ]; then \
		ditto -c -k --sequesterRsrc --keepParent _build/Payload "packages/XSign.ipa"; \
	else \
		ditto -c -k --sequesterRsrc --keepParent _build/Payload/XSign.app "packages/XSign_Catalyst.zip"; \
	fi
