import pixie, opengl, windy, vmath, core, layout, theme, tables, strutils

proc renderToImage*(win: Window): Image =
  result = newImage(win.winBounds.w.int, win.winBounds.h.int)
  result.fill(rgba(30, 30, 30, 255))
  # 1. Base UI
  result.draw(win.node)
  # 2. Overlays
  for o in win.overlays:
    if o.visible:
      result.draw(o.node)

proc updateTexture*(win: Window, img: Image) =
  if win.texture == 0: glGenTextures(1, addr win.texture)
  glBindTexture(GL_TEXTURE_2D, win.texture)
  glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA8.GLint, img.width.GLsizei, img.height.GLsizei, 0, GL_RGBA, GL_UNSIGNED_BYTE, addr img.data[0])
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR.GLint)
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR.GLint)

proc drawTexture*(win: Window) =
  glEnable(GL_TEXTURE_2D)
  glBindTexture(GL_TEXTURE_2D, win.texture)
  glBegin(GL_QUADS)
  glTexCoord2f(0, 1); glVertex2f(-1, -1)
  glTexCoord2f(1, 1); glVertex2f(1, -1)
  glTexCoord2f(1, 0); glVertex2f(1, 1)
  glTexCoord2f(0, 0); glVertex2f(-1, 1)
  glEnd()

proc updateAndDraw*(gui: SvgGui) =
  gui.processTimers()
  gui.layoutCtx.resetContext()
  for win in gui.windows:
    if win.windyWindow == nil: continue
    win.windyWindow.makeContextCurrent()

    # Run layout for base tree
    let rootId = gui.layoutCtx.prepareLayout(win)
    gui.layoutCtx.setSize(rootId, [win.windyWindow.size.x.float32, win.windyWindow.size.y.float32])
    gui.layoutCtx.runContext()
    gui.layoutCtx.applyLayout(win)

    # Run layout for overlays (if they have layout needs)
    for o in win.overlays:
        if o.visible:
            let oid = gui.layoutCtx.prepareLayout(o)
            # Overlays often have fixed sizes or are pre-calculated
            gui.layoutCtx.runContext()
            gui.layoutCtx.applyLayout(o)

    applyStyles(win)
    for o in win.overlays: applyStyles(o)

    let img = renderToImage(win)
    win.updateTexture(img)
    glClear(GL_COLOR_BUFFER_BIT)
    win.drawTexture()
    win.windyWindow.swapBuffers()
