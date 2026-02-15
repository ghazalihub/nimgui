import core, pixie, vmath, layout

var parentStack: seq[Widget] = @[]

template withParent(p: Widget, body: untyped) =
  let oldLen = parentStack.len
  parentStack.add(p)
  body
  parentStack.setLen(oldLen)

proc currentParent(): Widget =
  if parentStack.len > 0: parentStack[^1] else: nil

template uiWindow*(titleStr: string, body: untyped): Window =
  let win = Window() # Should be properly initialized
  win.visible = true
  withParent(win):
    body
  win

template uiRow*(body: untyped) =
  let g = newWidget(newSvgGroup())
  g.layContain = uint32(LAY_ROW) or uint32(LAY_FLEX)
  let p = currentParent()
  if p != nil: p.addChild(g)
  withParent(g):
    body

template uiColumn*(body: untyped) =
  let g = newWidget(newSvgGroup())
  g.layContain = uint32(LAY_COLUMN) or uint32(LAY_FLEX)
  let p = currentParent()
  if p != nil: p.addChild(g)
  withParent(g):
    body

template uiButton*(titleStr: string) =
  let b = newWidget(newSvgGroup()) # Placeholder for Button implementation
  let p = currentParent()
  if p != nil: p.addChild(b)

template uiLabel*(textStr: string) =
  let t = newWidget(newSvgText())
  let p = currentParent()
  if p != nil: p.addChild(t)
