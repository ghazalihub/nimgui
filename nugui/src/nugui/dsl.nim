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

template uiCheckbox*(labelStr: string, checkedVal: bool = false, onToggledProc: proc(c: bool) = nil) =
  let r = newWidget(newSvgGroup())
  r.layContain = uint32(LAY_ROW) or uint32(LAY_FLEX)
  let cb = newCheckbox(checkedVal)
  cb.onToggled = onToggledProc
  r.addChild(cb)
  r.addChild(newLabel(labelStr))
  let p = currentParent()
  if p != nil: p.addChild(r)

template uiSlider*(val: float32 = 0.0, onChangeProc: proc(v: float32) = nil) =
  let s = newSlider(val)
  s.onChanged = onChangeProc
  let p = currentParent()
  if p != nil: p.addChild(s)

template uiProgressBar*(val: float32 = 0.0) =
  let pb = newProgressBar(val)
  let p = currentParent()
  if p != nil: p.addChild(pb)

template uiTabs*(titles: seq[string], onChange: proc(i: int) = nil) =
  let t = newTabs(titles)
  t.onTabChanged = onChange
  let p = currentParent()
  if p != nil: p.addChild(t)

template uiListView*(items: seq[string]) =
  let lv = newListView(items)
  let p = currentParent()
  if p != nil: p.addChild(lv)

template uiDataGrid*(cols: seq[string], data: seq[seq[string]]) =
  let dg = newDataGrid(cols, data)
  let p = currentParent()
  if p != nil: p.addChild(dg)

template uiTextEdit*(textVal: string = "", onChangeProc: proc(t: string) = nil) =
  let te = newTextEdit(textVal)
  te.onChanged = onChangeProc
  let p = currentParent()
  if p != nil: p.addChild(te)

# Expand to all other components...
template uiAccordion*(titleStr: string, body: untyped) =
  let a = Accordion(title: titleStr)
  a.node = newSvgGroup()
  let content = newWidget(newSvgGroup())
  withParent(content):
    body
  let ac = newAccordion(titleStr, content)
  let p = currentParent()
  if p != nil: p.addChild(ac)

template uiCard*(body: untyped) =
  let c = newCard()
  withParent(c):
    body
  let p = currentParent()
  if p != nil: p.addChild(c)

template uiSidebar*(body: untyped) =
  let s = newSidebar()
  withParent(s):
    body
  let p = currentParent()
  if p != nil: p.addChild(s)

template uiNavbar*(body: untyped) =
  let n = newNavbar()
  withParent(n):
    body
  let p = currentParent()
  if p != nil: p.addChild(n)

template uiRating*(stars: int = 0) =
  let r = newRating(stars)
  let p = currentParent()
  if p != nil: p.addChild(r)
