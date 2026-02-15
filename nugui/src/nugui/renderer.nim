import pixie, figdraw, figdraw/fignodes, figdraw/commons, chroma, vmath, core, layout, theme, tables, strutils

proc toFigColor*(c: pixie.Color): chroma.Color =
  chroma.rgba(c.r, c.g, c.b, c.a)

proc buildRenderList*(w: Widget, list: var RenderList, parentIdx: int = -1): int =
  var fig: Fig

  # Base rect for every widget for debugging or background
  fig = Fig(
    kind: nkRectangle,
    screenBox: w.computedRect,
    fill: chroma.rgba(0, 0, 0, 0).color
  )

  # Apply computed attributes
  theme.applyStyles(w) # Ensure attributes are up to date

  if w.attributes.hasKey("fill"):
    try:
      let c = theme.parseColor(w.attributes["fill"])
      fig.fill = c
    except: discard

  if w.node of SvgRect:
    let r = SvgRect(w.node)
    fig.corners = [r.rx, r.rx, r.rx, r.rx]
  elif w.node of SvgText:
    let t = SvgText(w.node)
    fig.kind = nkText
    fig.text = t.text
    fig.fill = chroma.rgba(242, 242, 242, 255).color # Default text color

  # State based classes override
  if "pressed" in w.classes:
    fig.fill = chroma.rgba(50, 128, 156, 255).color
  elif "hovered" in w.classes:
    fig.fill = chroma.rgba(66, 144, 172, 255).color

  let idx = if parentIdx == -1:
              list.addRoot(fig)
            else:
              list.addChild(parentIdx, fig)

  for child in w.children:
    if child.visible:
      discard buildRenderList(child, list, idx)

  return idx

proc renderWindow*(win: Window): Renders =
  var list = RenderList()
  discard buildRenderList(win, list)
  result = Renders(layers: initOrderedTable[ZLevel, RenderList]())
  result.layers[0.ZLevel] = list

proc drawToImage*(win: Window): Image =
  # Uses pixie to render the window
  result = newImage(win.winBounds.w.int, win.winBounds.h.int)
  result.draw(win.node)

proc updateAndDraw*(gui: SvgGui) =
  gui.processTimers()
  gui.layoutCtx.resetContext()
  for win in gui.windows:
    let rootId = gui.layoutCtx.prepareLayout(win)
    gui.layoutCtx.setSize(rootId, [win.windyWindow.size.x.float32, win.windyWindow.size.y.float32])
    gui.layoutCtx.runContext()
    gui.layoutCtx.applyLayout(win)

    # Optional: Draw to Image via Pixie
    # let img = win.drawToImage()

    # Optional: Generate FigDraw render list
    let renders = renderWindow(win)
