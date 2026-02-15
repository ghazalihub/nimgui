import pixie, figdraw, figdraw/fignodes, figdraw/commons, chroma, vmath, core, layout, tables, strutils

proc parseColor*(s: string): chroma.Color =
  if s.startsWith("#"):
    let hex = s.strip(chars = {'#'})
    if hex.len == 6:
      let r = fromHex[uint8](hex[0..1])
      let g = fromHex[uint8](hex[2..3])
      let b = fromHex[uint8](hex[4..5])
      return chroma.rgba(r, g, b, 255).color
  return chroma.rgba(200, 200, 200, 255).color

proc buildRenderList*(w: Widget, list: var RenderList, parentIdx: int = -1): int =
  var fig: Fig

  fig = Fig(
    kind: nkRectangle,
    screenBox: w.computedRect,
    fill: chroma.rgba(0, 0, 0, 0).color
  )

  # Apply state-based classes (if implemented in logic)
  if "pressed" in w.classes:
    fig.fill = chroma.rgba(50, 128, 156, 255).color
  elif "hovered" in w.classes:
    fig.fill = chroma.rgba(66, 144, 172, 255).color
  elif "pushbutton" in w.classes:
    fig.fill = chroma.rgba(85, 85, 85, 255).color

  if w.node of SvgRect:
    let r = SvgRect(w.node)
    fig.corners = [r.rx, r.rx, r.rx, r.rx]
  elif w.node of SvgText:
    let t = SvgText(w.node)
    fig.kind = nkText
    fig.text = t.text
    fig.fill = chroma.rgba(242, 242, 242, 255).color

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
  gui.layoutCtx.resetContext()
  for win in gui.windows:
    let rootId = gui.layoutCtx.prepareLayout(win)
    gui.layoutCtx.setSize(rootId, [win.windyWindow.size.x.float32, win.windyWindow.size.y.float32])
    gui.layoutCtx.runContext()
    gui.layoutCtx.applyLayout(win)

    let renders = renderWindow(win)
    # Backend would draw renders here
