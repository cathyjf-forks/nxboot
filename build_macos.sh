#!/bin/zsh
set -euo pipefail

# This script builds only the universal macOS binary `nxboot`.

target_property() {
  bundle exec xcodeproj show NXBoot.xcodeproj --no-ansi --format=tree_hash \
    | yj \
    | jq -r \
      '.rootObject.targets[]
      |select(.name=="NXBoot")
      |.buildConfigurationList.buildConfigurations[]
      |select(.name=="Release").buildSettings.'$1
}

version=$(target_property MARKETING_VERSION)
buildno=$(target_property CURRENT_PROJECT_VERSION)
bundleid=$(target_property PRODUCT_BUNDLE_IDENTIFIER)
distdir=dist
tmpdir=DerivedData/bin
mkdir -p {$distdir,$tmpdir}/macos

echo "Building nxboot universal binary..."
cmd_srcs=(NXBootCmd/*.m NXBootKit/*.m)
cmd_cflags=(-DNXBOOT_VERSION=\"$version\" -DNXBOOT_BUILDNO=$buildno -D__OPEN_SOURCE__=1 -I. \
  -INXBootKit -std=gnu11 -fobjc-arc -fobjc-weak -fvisibility=hidden -Wall -O2)
cmd_fwkflags=(-framework CoreFoundation -framework Foundation -framework IOKit)
cmd_ldflags=(-sectcreate __TEXT __intermezzo Shared/intermezzo.bin)

# The binaries for x64_64 and arm64 are built separately and them combined with lipo(1),
# rather than just directly building a universal binary with clang, because the minimum
# macOS version is different for each of the two architectures. If we were willing to
# increase the minimum macOS version to 11.0, we could instead build the unviersal binary
# directly by supplying `-arch x86_64 -arch arm64` to a single invocation of clang(1).

xcrun clang "${cmd_srcs[@]}" "${cmd_cflags[@]}" "${cmd_fwkflags[@]}" "${cmd_ldflags[@]}" \
  -arch x86_64 -mmacosx-version-min=10.11 -o "$tmpdir/macos/nxboot.x86_64"
xcrun clang "${cmd_srcs[@]}" "${cmd_cflags[@]}" "${cmd_fwkflags[@]}" "${cmd_ldflags[@]}" \
  -arch arm64 -mmacosx-version-min=11.0 -o "$tmpdir/macos/nxboot.arm64"
xcrun lipo -create -output "$distdir/macos/nxboot" "$tmpdir/macos/nxboot".*
echo "macOS executable available at $distdir/macos/nxboot"