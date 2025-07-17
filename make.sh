#/bin/sh

# NOTE(sichirc): import TEAM_ID and IDENTITY variables. 
# you can get TEAM_ID from apple developer portal https://developer.apple.com
# IDENTITY can be obtained from security `find-identity -v -p codesigning`, but before you need to 
# in KeyChain Access app create 'Request a certificate from certificate authority'
# in https://developer.apple.com create certificate with request created before for development 
# download certificate
# add it to KeyChain Access and obtain IDENTITY
source ./variables.sh

export APP_NAME=DuckApp
export BUNDLE_ID=ru.DuckApp
export BUNDLE_VERSION=1.0.0
export BUNDLE_SHORT_VERSION=1.0
export BUNDLE_EXECUTABLE=${APP_NAME}
export MIN_SYSTEM_VERSION=10.14

PROJECT=${APP_NAME}

XCODE_PROJ_FOLDER=${PROJECT}.xcodeproj
XCODE_PBPROJ=project.pbxproj
export BUNDLE=DuckApp.app
OBJCFLAGS="-ObjC -Wall -Wextra -Wpedantic -Werror -framework UIKit -framework Foundation -framework QuartzCore -framework CoreGraphics"
LDFLAGS=""
SRC=ios_app.m
SIM_SYSROOT=$(xcrun --sdk iphonesimulator --show-sdk-path)
SIM_TARGET="arm64-apple-ios18.1-simulator"
IOS_TARGET="arm64-apple-ios17.6"
IOS_SYS_ROOT=$(xcrun --sdk iphoneos --show-sdk-path)
PROVISIONING_PROFILE_NAME=DUCK_APP_PROFILE.mobileprovision
EMBEDDED_PROVISIONING_PROFILE=${BUNDLE}/embedded.mobileprovision
XCENT_FILE=${PROJECT}.xcent

process_template()
{
  awk '
  { 
    line = $0
    while (match(line, /{{[A-Z0-9_]+}}/)) {
      placeholder = substr(line, RSTART+2, RLENGTH-4)
      replacement = ENVIRON[placeholder]
      line = substr(line, 1, RSTART-1) replacement substr(line, RSTART+RLENGTH)
    }
    print line
  }' $1 > $2
}

generate_xcodeproj()
{
  if [ -e $XCODE_PROJ_FOLDER ]; then
    rm -fr $XCODE_PROJ_FOLDER
  fi
  mkdir $XCODE_PROJ_FOLDER
  pbxproj_path=$XCODE_PROJ_FOLDER/$XCODE_PBPROJ
  
  export ENTRY_POINT_REF=$(hexdump -n 12 -e '12/1 "%02x"' /dev/urandom)
  export BUNDLE_REF=$(hexdump -n 12 -e '12/1 "%02x"' /dev/urandom)
  export ENTRY_POINT_PATH_REF=$(hexdump -n 12 -e '12/1 "%02x"' /dev/urandom)
  export ENTRY_PBXGROUP_REF=$(hexdump -n 12 -e '12/1 "%02x"' /dev/urandom)
  export BUNDLE_PBXGROUP_REF=$(hexdump -n 12 -e '12/1 "%02x"' /dev/urandom)
  export APP_NATIVE_TARGET_REF=$(hexdump -n 12 -e '12/1 "%02x"' /dev/urandom)
  export BUILD_CFG_LIST_REF=$(hexdump -n 12 -e '12/1 "%02x"' /dev/urandom)
  export ENTRY_PBXSOURCES_REF=$(hexdump -n 12 -e '12/1 "%02x"' /dev/urandom)
  export APP_BUILD_CONFIG_LIST_REF=$(hexdump -n 12 -e '12/1 "%02x"' /dev/urandom)
  export PBXROOT_REF=$(hexdump -n 12 -e '12/1 "%02x"' /dev/urandom)
  export DEBUG_XCBUILD_CONFIG_REF=$(hexdump -n 12 -e '12/1 "%02x"' /dev/urandom)
  export DEBUG_XCBUILD_SETTINGS_REF=$(hexdump -n 12 -e '12/1 "%02x"' /dev/urandom)

  process_template ./templates/project.pbxproj.tt $pbxproj_path

  xcschemes_path="${XCODE_PROJ_FOLDER}/xcuserdata/$(whoami).xcuserdatad/xcschemes"
  mkdir -p $xcschemes_path
  touch "${xcschemes_path}/xcschememanagement.plist"
  process_template "./templates/xcschememanagement.plist.tt" "$xcschemes_path/xcschememanagement.plist"

  mkdir "${XCODE_PROJ_FOLDER}/xcshareddata"

  xcworkspace_path="${XCODE_PROJ_FOLDER}/project.xcworkspace"
  mkdir -p "${xcworkspace_path}/xcshareddata/swiftpm/configuration"
  mkdir -p "${xcworkspace_path}/xcuserdata/$(whoami).xcuserdatad"

  touch "${xcworkspace_path}/contents.xcworkspacedata"
  cat > "${xcworkspace_path}/contents.xcworkspacedata" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<Workspace
   version = "1.0">
   <FileRef
      location = "self:">
   </FileRef>
</Workspace>
EOF
}


case $1 in 
  'build')
    case $2 in
      '')
      rm -fr $BUNDLE
      mkdir $BUNDLE
      clang -o "$BUNDLE/$PROJECT" -g -O0 $OBJCFLAGS $LDFLAGS $SRC -isysroot $SIM_SYSROOT -target $SIM_TARGET
      process_template ./templates/info-plist.tt "$BUNDLE/Info.plist"
      ;;
      'device')
      echo "build for device $IOS_TARGET"
      rm -fr $BUNDLE
      mkdir $BUNDLE
      clang -o "$BUNDLE/$PROJECT" -g -O0 $OBJCFLAGS $SRC -isysroot $IOS_SYS_ROOT -target $IOS_TARGET
      process_template ./templates/info-plist.tt "$BUNDLE/Info.plist"
      process_template ./templates/app.xcent.tt "${XCENT_FILE}"
      echo "Code Signing"
      cp ${PROVISIONING_PROFILE_NAME} ${EMBEDDED_PROVISIONING_PROFILE}
      codesign \
        --force \
        --timestamp=none \
        --sign ${IDENTITY} \
        --entitlements ${XCENT_FILE} \
        ${BUNDLE}
      ;;
    esac 
    ;;
  run)
    case $2 in
      'sim')
        open -a "Simulator.app"
        xcrun simctl install booted $BUNDLE
        if [[ $(pidof $PROJECT) ]]; then 
          xcrun simctl terminate booted $BUNDLE_ID
        fi
        xcrun simctl launch --console-pty booted $BUNDLE_ID
      ;;
      'device')
        DEVICE_ID=$(xcrun devicectl list devices | awk '{ print $3 }' | sed -n 4p)
        if [[ $DEVICE_ID ]]; then
          echo "installing app on $DEVICE_ID"
          INSTALLATION_URL=$(xcrun devicectl device install app --device $DEVICE_ID $BUNDLE --hide-headers --hide-default-columns | awk 'sub(/.*installationURL\:/, ""){print $0}')
          xcrun devicectl device process launch -v --console --device $DEVICE_ID $INSTALLATION_URL
        else
          echo "no connected devices"
          echo "you can use `xcrun devicectl list devices`"
        fi
      ;;
    esac
    ;;    
  debug)
    case $2 in
      '')
        lldb -n DuckApp
        ;;
      wait)
        lldb -n DuckApp -w
        ;;
    esac
    ;;
  clean)
		rm -fr $BUNDLE
    ;; 
  xcodeproj)
    generate_xcodeproj
    ;;
esac

