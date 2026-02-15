import pixie, figdraw, figdraw/fignodes, figdraw/commons, chroma, vmath, core, layout, tables, strutils

proc parseColor*(s: string): chroma.Color =
  if s.startsWith("#"):
    let hex = s.strip(chars = {'#'})
    if hex.len == 6:
      let r = fromHex[uint8](hex[0..1])
      let g = fromHex[uint8](hex[2..3])
      let b = fromHex[uint8](hex[4..5])
      return chroma.rgba(r, g, b, 255).color
  return chroma.rgba(0, 0, 0, 255).color

proc buildRenderList*(w: Widget, list: var RenderList, parentIdx: int = -1): int =
  var fig: Fig

  fig = Fig(
    kind: nkRectangle,
    screenBox: w.computedRect,
    fill: chroma.rgba(0, 0, 0, 0).color
  )

  # Map attributes
  if w.attributes.hasKey("fill"):
    fig.fill = parseColor(w.attributes["fill"])

  if w.attributes.hasKey("opacity"):
    let op = parseFloat(w.attributes["opacity"])
    fig.fill.a = fig.fill.a * op

  if w.node of SvgRect:
    let r = SvgRect(w.node)
    fig.corners = [r.rx, r.rx, r.rx, r.rx]
    if w.attributes.hasKey("stroke"):
      fig.stroke = RenderStroke(
        weight: parseFloat(w.attributes.getOrDefault("stroke-width", "1.0")),
        color: parseColor(w.attributes["stroke"])
      )
  elif w.node of SvgText:
    let t = SvgText(w.node)
    fig.kind = nkText
    fig.text = t.text
    if not w.attributes.hasKey("fill"):
      fig.fill = chroma.rgba(255, 255, 255, 255).color

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
