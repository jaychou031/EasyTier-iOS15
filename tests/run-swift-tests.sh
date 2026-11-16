#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
# These executables run on the macOS host, not on an iOS device. Do not let
# deployment settings inherited from an archive job retarget Clang to iOS.
unset IPHONEOS_DEPLOYMENT_TARGET TVOS_DEPLOYMENT_TARGET WATCHOS_DEPLOYMENT_TARGET XROS_DEPLOYMENT_TARGET
export SDKROOT="$(xcrun --sdk macosx --show-sdk-path)"
export MACOSX_DEPLOYMENT_TARGET=13.0
host_target="$(uname -m)-apple-macosx${MACOSX_DEPLOYMENT_TARGET}"
mkdir -p .build/tests
test_dir=$(mktemp -d "$PWD/.build/tests/tunnel.XXXXXX")
trap 'rm -rf "$test_dir"' EXIT
xcrun --sdk macosx swiftc -sdk "$SDKROOT" -target "$host_target" \
  -swift-version 6 \
  -emit-module -emit-library -module-name EasyTierShared \
  -module-cache-path "$test_dir/cache" EasyTierShared/EasyTierShared.swift \
  -o "$test_dir/libEasyTierShared.dylib"
xcrun --sdk macosx clang -isysroot "$SDKROOT" -target "$host_target" \
  -I EasyTierNetworkExtension -c tests/tunnel_ffi_stubs.c -o "$test_dir/stubs.o"
# Keep private lifecycle methods private in production. Appending the tests to
# the same Swift file lets the harness drive the real provider without a VPN.
cat EasyTierNetworkExtension/PacketTunnelProvider.swift tests/TunnelLifecycleTests.swift > "$test_dir/ProviderTests.swift"
xcrun --sdk macosx swiftc -sdk "$SDKROOT" -target "$host_target" -swift-version 5 -parse-as-library \
  -I "$test_dir" -L "$test_dir" -lEasyTierShared -Xlinker -rpath -Xlinker "$test_dir" \
  -module-cache-path "$test_dir/cache" -I EasyTierNetworkExtension \
  -import-objc-header tests/tunnel_ffi_stubs.h \
  "$test_dir/ProviderTests.swift" tests/PacketTunnelProviderStub.swift \
  EasyTierNetworkExtension/{AddressHelper,BuilderHelper,InfoModels,OSLogExporter,TunnelHelper}.swift \
  "$test_dir/stubs.o" -o "$test_dir/web-tests"
"$test_dir/web-tests"
xcrun --sdk macosx swiftc -sdk "$SDKROOT" -target "$host_target" -swift-version 5 -parse-as-library \
  -I "$test_dir" -L "$test_dir" -lEasyTierShared -Xlinker -rpath -Xlinker "$test_dir" \
  -module-cache-path "$test_dir/cache" \
  EasyTier/Views/DashboardView+Profiles.swift tests/ProfileSelectionTests.swift \
  -o "$test_dir/profile-tests"
"$test_dir/profile-tests"
xcrun --sdk macosx swiftc -sdk "$SDKROOT" -target "$host_target" -swift-version 5 -parse-as-library \
  -I "$test_dir" -L "$test_dir" -lEasyTierShared -Xlinker -rpath -Xlinker "$test_dir" \
  -module-cache-path "$test_dir/cache" \
  tests/VPNPreferencesTests.swift -o "$test_dir/preferences-tests"
"$test_dir/preferences-tests"
