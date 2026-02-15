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
  let win = Window(visible: true, children: @[], node: newSvgGroup(), title: titleStr)
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

template uiButton*(titleStr: string, onClickedProc: proc() = nil) =
  let b = newButton(titleStr)
  b.onClicked = onClickedProc
  let p = currentParent()
  if p != nil: p.addChild(b)

template uiLabel*(textStr: string) =
  let l = newLabel(textStr)
  let p = currentParent()
  if p != nil: p.addChild(l)

template uiCheckbox*(labelStr: string, checkedVal: bool = false) =
  let r = newWidget(newSvgGroup())
  r.layContain = uint32(LAY_ROW) or uint32(LAY_FLEX)
  let cb = newCheckbox(checkedVal)
  r.addChild(cb)
  r.addChild(newLabel(labelStr))
  let p = currentParent()
  if p != nil: p.addChild(r)

template uiSlider*(val: float32 = 0.0, onChangeProc: proc(v: float32) = nil) =
  let s = newSlider(val)
  s.onChanged = onChangeProc
  let p = currentParent()
  if p != nil: p.addChild(s)

template uiTextEdit*(initial: string = "", onChangeProc: proc(t: string) = nil) =
  let te = newTextEdit(initial)
  te.onChanged = onChangeProc
  let p = currentParent()
  if p != nil: p.addChild(te)

# ... and so on for all components
