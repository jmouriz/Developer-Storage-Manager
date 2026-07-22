on run arguments
    set volumeName to item 1 of arguments
    set backgroundFile to POSIX file ("/Volumes/" & volumeName & "/Xcode Storage Manager.app/Contents/Resources/DMGBackground.png") as alias

    tell application "Finder"
        set targetDisk to disk volumeName
        tell targetDisk
            open
            tell container window
                set current view to icon view
                set toolbar visible to false
                set statusbar visible to false
                set pathbar visible to false
                set bounds to {120, 120, 1320, 880}
            end tell

            set viewOptions to icon view options of container window
            tell viewOptions
                set arrangement to not arranged
                set icon size to 128
                set text size to 14
                set label position to bottom
                set background picture to backgroundFile
            end tell

            set position of item "Xcode Storage Manager.app" to {300, 360}
            set position of item "Applications" to {925, 360}
            set extension hidden of item "Xcode Storage Manager.app" to true
            update without registering applications
            delay 2
            close
        end tell
    end tell
end run
