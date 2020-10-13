# Font loader
import sdl2, sdl2/ttf

# Types
type
  SDLException* = object of IOError
  
  Font* = ref object
    file*: string
    size*: int

template sdlFailIf*(cond: typed, reason: string) =
  if cond: raise SDLException.newException(
    reason & ", SDL error: " & $getError())

# List fonts
var fontList = newSeq[Font]()

var fontA = Font(file: "assets/fonts/SourceSansProSemiBold.ttf", size: 18)
var fontB = Font(file: "assets/fonts/SourceSansProBold.ttf", size: 32)

fontList.add(fontA)
fontList.add(fontB)


# Load fonts!
proc loadFonts*(): seq[FontPtr] =
  
    for font in fontList:
        var file = openFont(font.file, cint(font.size))
        sdlFailIf file.isNil: "Failed to load font"
        result.add(file)