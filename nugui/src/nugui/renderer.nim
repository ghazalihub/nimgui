import pixie, figdraw, figdraw/fignodes, figdraw/commons, chroma, vmath, core, layout, tables

proc toFigColor(c: pixie.Color): chroma.Color =
  chroma.rgba(c.r, c.g, c.b, c.a)

proc buildRenderList*(w: Widget, list: var RenderList, parentIdx: int = -1): int =
  var fig: Fig

  # Initialize with defaults
  fig = Fig(
    kind: nkRectangle,
    screenBox: w.computedRect,
    fill: chroma.rgba(0, 0, 0, 0).color
  )

  if w.node of SvgRect:
    let r = SvgRect(w.node)
    # Map more properties from w.node. style is not easily accessible in pixie
    # We might need to store style on the Widget itself if pixie doesn't provide it
    fig.fill = chroma.rgba(200, 200, 200, 255).color # Placeholder
  elif w.node of SvgText:
    let t = SvgText(w.node)
    fig.kind = nkText
    fig.text = t.text
    # Need to handle font etc.
  elif w.node of SvgGroup:
    discard # Keep as empty rect container

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

proc drawGui*(gui: SvgGui) =
  # Main entry point to layout and render all windows
  gui.layoutCtx.resetContext()
  for win in gui.windows:
    let rootId = gui.layoutCtx.prepareLayout(win)
    gui.layoutCtx.setSize(rootId, [win.windyWindow.size.x.float32, win.windyWindow.size.y.float32])
    gui.layoutCtx.runContext()
    gui.layoutCtx.applyLayout(win)

    # After layout, we can render
    let renders = renderWindow(win)
    # Feed renders to figdraw backend (need figdraw initialized)
    # This usually happens in the main loop
