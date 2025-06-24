#!/bin/bash

# --- Configuration ---
# !!! IMPORTANT: Adjust these paths and names before running !!!
APP_NAME="MoveMouseMac.app"
# Path to the FOLDER where Xcode archives and exports your .app bundle.
# Example: If you export to a folder named "BuildOutput" on your Desktop,
# then SOURCE_APP_FOLDER_PATH="$HOME/Desktop/BuildOutput"
# The script expects APP_NAME to be INSIDE this SOURCE_APP_FOLDER_PATH.
SOURCE_APP_FOLDER_PATH="$HOME/Desktop/MoveMouseMacBuild" # <--- !!! CHECK AND CHANGE THIS !!!

DMG_OUTPUT_NAME="MoveMouseMac.dmg"
DMG_VOLUME_NAME="MoveMouseMac" # The name of the mounted volume when DMG is opened

# Path where the final DMG will be saved.
# Example: Save to Desktop: DMG_OUTPUT_FOLDER_PATH="$HOME/Desktop"
DMG_OUTPUT_FOLDER_PATH="${SOURCE_APP_FOLDER_PATH}" # <--- !!! CHECK AND CHANGE THIS IF NEEDED !!!

# --- Derived paths ---
APP_SOURCE_PATH="${SOURCE_APP_FOLDER_PATH}/${APP_NAME}"
FINAL_DMG_PATH="${DMG_OUTPUT_FOLDER_PATH}/${DMG_OUTPUT_NAME}"
TEMP_DMG_NAME="${DMG_OUTPUT_FOLDER_PATH}/temp_${DMG_OUTPUT_NAME}" # Temporary DMG in the output folder

echo "----------------------------------------------------"
echo "MoveMouseMac DMG Creation Script"
echo "----------------------------------------------------"
echo "APP_NAME: ${APP_NAME}"
echo "SOURCE_APP_FOLDER_PATH (where .app is): ${SOURCE_APP_FOLDER_PATH}"
echo "DMG_OUTPUT_FOLDER_PATH (where .dmg will be saved): ${DMG_OUTPUT_FOLDER_PATH}"
echo "DMG_VOLUME_NAME: ${DMG_VOLUME_NAME}"
echo "FINAL_DMG_PATH: ${FINAL_DMG_PATH}"
echo "----------------------------------------------------"
echo ""

# --- Check if .app exists ---
if [ ! -d "${APP_SOURCE_PATH}" ]; then
    echo "❌ Error: Application bundle not found at ${APP_SOURCE_PATH}"
    echo "Please ensure the APP_NAME and SOURCE_APP_FOLDER_PATH variables are set correctly."
    echo "Xcode typically archives to a path like: ~/Library/Developer/Xcode/Archives"
    echo "And you would then 'Distribute App' -> 'Copy App' to a folder like the one specified in SOURCE_APP_FOLDER_PATH."
    exit 1
fi

# --- Create output directory if it doesn't exist ---
mkdir -p "${DMG_OUTPUT_FOLDER_PATH}"

# --- Remove existing final DMG if it exists to prevent hdiutil errors ---
if [ -f "${FINAL_DMG_PATH}" ]; then
    echo "ℹ️ Existing DMG found at ${FINAL_DMG_PATH}. Removing it first."
    rm -f "${FINAL_DMG_PATH}"
fi
if [ -f "${TEMP_DMG_NAME}" ]; then
    echo "ℹ️ Existing temporary DMG found. Removing it."
    rm -f "${TEMP_DMG_NAME}"
fi

# --- Create a temporary read-write DMG based on the size of the .app ---
echo "⏳ Creating temporary DMG from application..."
# Using -srcfolder directly with the .app bundle path
hdiutil create -ov -volname "${DMG_VOLUME_NAME}" -fs HFS+ -srcfolder "${APP_SOURCE_PATH}" -format UDRW "${TEMP_DMG_NAME}"

if [ $? -ne 0 ]; then
    echo "❌ Error creating temporary DMG from ${APP_SOURCE_PATH}."
    exit 1
fi
echo "✅ Temporary DMG created: ${TEMP_DMG_NAME}"

# --- (Optional) Mount, customize (add /Applications symlink, background), unmount ---
# This section is for manual or more advanced scripting.
# To add a symlink to /Applications and a background image, you would:
# 1. Mount the TEMP_DMG_NAME:
#    MOUNT_OUTPUT=$(hdiutil attach -readwrite -noverify -noautoopen "${TEMP_DMG_NAME}")
#    MOUNT_POINT=$(echo "${MOUNT_OUTPUT}" | egrep '/Volumes/' | sed -n 's/.*\(\/Volumes\/[^ ]*\).*/\1/p')
#    if [ -z "${MOUNT_POINT}" ]; then echo "Error mounting"; exit 1; fi
# 2. Create Applications symlink:
#    ln -sf /Applications "${MOUNT_POINT}/Applications"
# 3. Add background image (requires pre-existing .background folder and image in your source, or use AppleScript):
#    cp MyDMGBackground.png "${MOUNT_POINT}/.background.png"
#    # Then set view options, often via AppleScript for finder window properties
# 4. Unmount:
#    hdiutil detach "${MOUNT_POINT}"
# For simplicity, this script skips these visual customizations.

# --- Convert to compressed read-only DMG ---
echo "⏳ Converting to final compressed read-only DMG..."
hdiutil convert "${TEMP_DMG_NAME}" -format UDZO -imagekey zlib-level=9 -o "${FINAL_DMG_PATH}"

if [ $? -ne 0 ]; then
    echo "❌ Error converting DMG to compressed format UDZO."
    rm -f "${TEMP_DMG_NAME}" # Clean up temp DMG
    exit 1
fi
echo "✅ Final DMG created: ${FINAL_DMG_PATH}"

# --- Clean up ---
echo "🧹 Cleaning up temporary DMG..."
rm -f "${TEMP_DMG_NAME}"

echo "🎉 DMG creation complete!"
echo "   Your DMG is located at: ${FINAL_DMG_PATH}"
echo "----------------------------------------------------"
exit 0
```
