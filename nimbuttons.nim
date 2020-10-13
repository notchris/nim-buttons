# Buttons (and hopefuly more soon) for nim!
# Made by notchris \o/

import sdl2, sdl2/ttf, sdl2/gfx, basic2d, times, json, colors, os, fonts
var running: bool = true

# Types
type
  SDLException = object of IOError

  CacheLine = object
    texture: TexturePtr
    w, h: cint

  TextCache = ref object
    text: string
    cache: array[2, CacheLine]

  Vec2* = object
    x*: cint
    y*: cint

  Button* = ref object
    id*: int
    label*: string
    pos*: Point2d
    font*: FontPtr
    size*: Vector2d
    padding*: Vector2d
    bgColor*: colors.Color
    bgColorHover*: colors.Color
    textColor*: colors.Color
    radius*: int

  Container* = ref object
    loading*: bool
    mouse*: Vec2
    renderer*: RendererPtr
    fonts*: seq[FontPtr]
    buttons*: seq[Button]
    cursorDefault*: CursorPtr
    cursorHover*: CursorPtr

  Block* = ref object
    size*: Vector2d
    pos*: Point2d
    fill*: colors.Color

# SDL Fail Template
template sdlFailIf(cond: typed, reason: string) =
  if cond: raise SDLException.newException(
    reason & ", SDL error: " & $getError())

# Procedures
proc newTextCache: TextCache =
  new result

proc renderText(renderer: RendererPtr, font: FontPtr, text: string,
                x, y, outline: cint, color: sdl2.Color): CacheLine =
  font.setFontOutline(outline)
  let surface = font.renderTextBlended(text.cstring, color)
  sdlFailIf surface.isNil: "Could not render text surface"

  discard surface.setSurfaceAlphaMod(color.a)

  result.w = surface.w
  result.h = surface.h
  result.texture = renderer.createTextureFromSurface(surface)
  sdlFailIf result.texture.isNil: "Could not create texture from rendered text"

  surface.freeSurface()

proc renderText(container: Container, text: string, x, y: cint, color: sdl2.Color,
                tc: TextCache) =
  let passes = [(color: color(0, 0, 0, 64), outline: 2.cint),
                (color: color, outline: 0.cint)]

  if text != tc.text:
    for i in 0..1:
      tc.cache[i].texture.destroy()
      tc.cache[i] = container.renderer.renderText(
        container.fonts[0], text, x, y, passes[i].outline, passes[i].color)
    tc.text = text

  for i in 0..1:
    var source = rect(0, 0, tc.cache[i].w, tc.cache[i].h)
    var dest = rect(x - passes[i].outline, y - passes[i].outline,
                    tc.cache[i].w, tc.cache[i].h)
    container.renderer.copyEx(tc.cache[i].texture, source, dest,
                         angle = 0.0, center = nil)

template renderTextCached(container: Container, text: string, x, y: cint, color: sdl2.Color) =
  block:
    var tc {.global.} = newTextCache()
    container.renderText(text, x, y, color, tc)

proc createButton (container: Container, id: int, label: string, font: FontPtr,
                  padding: Vector2d, bgColor: colors.Color, bgColorHover: colors.Color,
                  textColor: colors.Color, radius: int, pos: Point2d ): Button =
    var button = Button(
      id: id,
      label: label,
      font: font,
      padding: padding,
      bgColor: bgColor,
      bgColorHover: bgColorHover,
      textColor: textColor,
      radius: radius,
      pos: pos
    )
    var w: cint = 0
    var h: cint = 0
    var wptr: ptr cint = addr w
    var hptr: ptr cint = addr h
    var size = button.font.sizeText(label, wptr, hptr)
    button.size = vector2d(w.toFloat, h.toFloat)
    result = button

proc newContainer(renderer: RendererPtr): Container =
  new result
  result.renderer = renderer
  result.fonts = loadFonts()
  result.buttons = newSeq[Button]()
  result.cursorDefault = createSystemCursor(SDL_SYSTEM_CURSOR_ARROW)
  result.cursorHover = createSystemCursor(SDL_SYSTEM_CURSOR_HAND)

  result.buttons.add(
    result.createButton(
      1,
      "Primary",
      result.fonts[0],
      vector2d(10, 8),
      colors.Color(0x007AFE),
      colors.Color(0x0069d9),
      colors.Color(0xffffff),
      4,
      point2d(100, 100)
    )
  )

  result.buttons.add(
    result.createButton(
      2,
      "Success",
      result.fonts[0],
      vector2d(10, 8),
      colors.Color(0x28A745),
      colors.Color(0x218838),
      colors.Color(0xffffff),
      4,
      point2d(100, 140)
    )
  )

  result.buttons.add(
    result.createButton(
      3,
      "Danger",
      result.fonts[0],
      vector2d(10, 8),
      colors.Color(0xDC3545),
      colors.Color(0xc82333),
      colors.Color(0xffffff),
      4,
      point2d(100, 180)
    )
  )

  result.buttons.add(
    result.createButton(
      4,
      "Warning",
      result.fonts[0],
      vector2d(10, 8),
      colors.Color(0xFFC109),
      colors.Color(0xe0a800),
      colors.Color(0xffffff),
      4,
      point2d(100, 220)
    )
  )

  result.buttons.add(
    result.createButton(
      5,
      "Info",
      result.fonts[0],
      vector2d(10, 8),
      colors.Color(0x15A0B5),
      colors.Color(0x138496),
      colors.Color(0xffffff),
      4,
      point2d(100, 260)
    )
  )

proc mouseDown(container: Container) =
  echo container.mouse

proc containsPointer (container: Container, rect: Rect): bool =
  result = rect.x <= container.mouse.x and container.mouse.x <= rect.x + rect.w and
           rect.y <= container.mouse.y and container.mouse.y <= rect.y + rect.h

proc handleInput(container: Container) =
  var event = defaultEvent
  while pollEvent(event):
    case event.kind
    of QuitEvent:
      running = false
    of MouseButtonDown:
      var b = event.button.button
      if b == 1:
        container.mouseDown()
    of MouseMotion:
      var v = Vec2()
      v.x = event.evMouseMotion.x
      v.y = event.evMouseMotion.y
      container.mouse = v
    else:
      discard


proc render(container: Container) =
  setCursor(container.cursorDefault)

  for b in container.buttons:

    var bgColor = b.bgColor.extractRGB()
    var bgColorHover = b.bgColorHover.extractRGB()
    var textColor = b.textColor.extractRGB()

    var bgRgb = color(bgColor.r, bgColor.g, bgColor.b, 255)
    var textRgb = color(textColor.r, textColor.g, textColor.b, 255)

    var activeBg = bgColor

    var rect: Rect = (
      x: cint(b.pos.x - b.padding.x / 2),
      y: cint(b.pos.y - b.padding.y / 2),
      w: cint(b.size.x + b.padding.x),
      h: cint(b.size.y + b.padding.y)
    )

    
    if container.containsPointer(rect):
      activeBg = bgColorHover
      setCursor(container.cursorHover)
    else:
      activeBg = bgColor

    
    # Button Fill
    container.renderer.roundedBoxRGBA(
      int16(b.pos.x - b.padding.x / 2),
      int16(b.pos.y - b.padding.y / 2),
      int16((b.pos.x - b.padding.x / 2) + b.size.x + b.padding.x),
      int16((b.pos.y - b.padding.y / 2) + b.size.y + b.padding.y),
      int16(b.radius),
      uint8(activeBg.r),
      uint8(activeBg.g),
      uint8(activeBg.b),
      uint8(255)
    )

    # Button Stroke
    container.renderer.roundedRectangleRGBA(
      int16(b.pos.x - b.padding.x / 2),
      int16(b.pos.y - b.padding.y / 2),
      int16((b.pos.x - b.padding.x / 2) + b.size.x + b.padding.x),
      int16((b.pos.y - b.padding.y / 2) + b.size.y + b.padding.y),
      int16(b.radius),
      uint8(bgColorHover.r),
      uint8(bgColorHover.g),
      uint8(bgColorHover.b),
      uint8(255)
    )

    # Button Text
    container.renderTextCached(b.label, cint(b.pos.x), cint(b.pos.y), textRgb)


proc main =
  sdlFailIf(not sdl2.init(INIT_VIDEO or INIT_TIMER or INIT_EVENTS)):
    "SDL2 initialization failed"
  defer: sdl2.quit()

  sdlFailIf(not setHint("SDL_RENDER_SCALE_QUALITY", "2")):
    "Linear texture filtering could not be enabled"

  sdlFailIf(ttfInit() == SdlError): "SDL2 TTF initialization failed"
  defer: ttfQuit()

  # Create window
  let window = createWindow(title = "App",
    x = SDL_WINDOWPOS_CENTERED, y = SDL_WINDOWPOS_CENTERED,
    w = 640, h = 480, flags = SDL_WINDOW_SHOWN or SDL_WINDOW_OPENGL or SDL_WINDOW_ALLOW_HIGHDPI)
  sdlFailIf window.isNil: "Window could not be created"
  defer: window.destroy()
  
  # Create renderer
  let renderer = window.createRenderer(index = -1,
    flags = Renderer_Software)
  sdlFailIf renderer.isNil: "Renderer could not be created"
  defer: renderer.destroy()



  # Init container & renderer
  var container = newContainer(renderer)

  # App loop
  while running:
    container.handleInput()
    container.renderer.setDrawColor(255, 255, 255, 255)
    container.renderer.clear()
    container.render()
    container.renderer.present()

main()