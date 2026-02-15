import core, widgets, textedit, pixie, vmath, layout, tables

var parentStack: seq[Widget] = @[]

template withParent(p: Widget, body: untyped) =
  let oldLen = parentStack.len
  parentStack.add(p)
  body
  parentStack.setLen(oldLen)

proc currentParent(): Widget =
  if parentStack.len > 0: parentStack[^1] else: nil

template uiWindow*(titleStr: string, body: untyped): Window =
  let win = Window(visible: true, children: @[], node: newSvgGroup())
  # Properly initialize window with gui etc. in real use
  withParent(win):
    body
  win

template uiColumn*(body: untyped) =
  let g = newWidget(newSvgGroup())
  g.layContain = uint32(LAY_COLUMN) or uint32(LAY_FLEX)
  let p = currentParent()
  if p != nil: p.addChild(g)
  withParent(g):
    body

template uiRow*(body: untyped) =
  let g = newWidget(newSvgGroup())
  g.layContain = uint32(LAY_ROW) or uint32(LAY_FLEX)
  let p = currentParent()
  if p != nil: p.addChild(g)
  withParent(g):
    body

template uiButton*(titleStr: string, onClickedBody: untyped = nil) =
  let b = newButton(titleStr)
  let p = currentParent()
  if p != nil: p.addChild(b)
  # Handle onClickedBody if needed

template uiLabel*(textStr: string) =
  let l = newLabel(textStr)
  let p = currentParent()
  if p != nil: p.addChild(l)

template uiCheckbox*(checkedVal: bool = false) =
  let cb = newCheckbox(checkedVal)
  let p = currentParent()
  if p != nil: p.addChild(cb)

template uiSlider*(val: float32 = 0.0) =
  let s = newSlider(val)
  let p = currentParent()
  if p != nil: p.addChild(s)

template uiProgressBar*(val: float32 = 0.0) =
  let pb = newProgressBar(val)
  let p = currentParent()
  if p != nil: p.addChild(pb)

template uiTabs*(titles: seq[string]) =
  let t = newTabs(titles)
  let p = currentParent()
  if p != nil: p.addChild(t)

# ... add more for all 30+ widgets as needed
