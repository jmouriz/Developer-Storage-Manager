use framework "AppKit"

on run arguments
    set iconPath to item 1 of arguments
    set targetPath to item 2 of arguments
    set iconImage to current application's NSImage's alloc()'s initWithContentsOfFile:iconPath
    if iconImage is missing value then error "No se pudo cargar el ícono."

    set didSetIcon to current application's NSWorkspace's sharedWorkspace()'s setIcon:iconImage forFile:targetPath options:0
    if not (didSetIcon as boolean) then error "Finder no pudo asignar el ícono personalizado."
end run
