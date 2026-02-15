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
  win.addClass("window")
  withParent(win):
    body
  win

template uiColumn*(body: untyped) =
  let g = newWidget(newSvgGroup())
  g.node.metadata["layout"] = "flex"
  g.node.metadata["flex-direction"] = "column"
  let p = currentParent()
  if p != nil: p.addChild(g)
  withParent(g):
    body

template uiRow*(body: untyped) =
  let g = newWidget(newSvgGroup())
  g.node.metadata["layout"] = "flex"
  g.node.metadata["flex-direction"] = "row"
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
  let cb = newCheckbox(labelStr, checkedVal)
  cb.onToggled = onToggledProc
  let p = currentParent()
  if p != nil: p.addChild(cb)

template uiSwitch*(labelStr: string, checkedVal: bool = false, onToggledProc: proc(c: bool) = nil) =
  let sw = newSwitch(labelStr, checkedVal)
  sw.onToggled = onToggledProc
  let p = currentParent()
  if p != nil: p.addChild(sw)

template uiRadio*(labelStr: string, checkedVal: bool = false) =
  let r = newRadio(labelStr, checkedVal)
  let p = currentParent()
  if p != nil: p.addChild(r)

template uiSlider*(val: float32 = 0.5, onChangeProc: proc(v: float32) = nil) =
  let s = newSlider(val)
  s.onChanged = onChangeProc
  let p = currentParent()
  if p != nil: p.addChild(s)

template uiRangeSlider*() =
  let s = newRangeSlider()
  let p = currentParent()
  if p != nil: p.addChild(s)

template uiProgressBar*(val: float32 = 0.0) =
  let pb = newProgressBar(val)
  let p = currentParent()
  if p != nil: p.addChild(pb)

template uiSpinner*() =
  let s = newSpinner()
  let p = currentParent()
  if p != nil: p.addChild(s)

template uiTextBox*(textVal: string = "", onChangeProc: proc(t: string) = nil) =
  let tb = newTextBox(textVal)
  tb.onChanged = onChangeProc
  let p = currentParent()
  if p != nil: p.addChild(tb)

template uiSearchInput*() =
  let s = newSearchInput()
  let p = currentParent()
  if p != nil: p.addChild(s)

template uiPasswordInput*() =
  let s = newPasswordInput()
  let p = currentParent()
  if p != nil: p.addChild(s)

template uiComboBox*(options: seq[string]) =
  let c = newComboBox(options)
  let p = currentParent()
  if p != nil: p.addChild(c)

template uiTabs*(titles: seq[string], onChange: proc(i: int) = nil) =
  let t = newTabs(titles)
  t.onTabChanged = onChange
  let p = currentParent()
  if p != nil: p.addChild(t)

template uiAccordion*(titleStr: string, body: untyped) =
  let ac = newAccordion(titleStr)
  withParent(ac):
    body
  let p = currentParent()
  if p != nil: p.addChild(ac)

template uiCard*(titleStr: string, body: untyped) =
  let c = newCard(titleStr)
  withParent(c):
    body
  let p = currentParent()
  if p != nil: p.addChild(c)

template uiScrollArea*(body: untyped) =
  let container = newWidget(newSvgGroup())
  withParent(container):
    body
  let sa = newScrollArea(container)
  let p = currentParent()
  if p != nil: p.addChild(sa)

template uiDataGrid*(headers: seq[string], data: seq[seq[string]]) =
  let dg = newDataGrid(headers, data)
  let p = currentParent()
  if p != nil: p.addChild(dg)

template uiTreeView*(body: untyped) =
  let tv = newListView()
  tv.addClass("tree-view")
  withParent(tv):
    body
  let p = currentParent()
  if p != nil: p.addChild(tv)

template uiTreeItem*(labelStr: string, body: untyped = nil) =
  let ti = newTreeItem(labelStr)
  if body != nil:
    withParent(ti):
      body
  let p = currentParent()
  if p != nil: p.addChild(ti)

template uiBadge*(textStr: string) =
  let b = newBadge(textStr)
  let p = currentParent()
  if p != nil: p.addChild(b)

template uiAvatar*(initialsStr: string) =
  let a = newAvatar(initialsStr)
  let p = currentParent()
  if p != nil: p.addChild(a)

template uiRating*(stars: int = 0) =
  let r = newRating(stars)
  let p = currentParent()
  if p != nil: p.addChild(r)

template uiTag*(labelStr: string) =
  let t = newTag(labelStr)
  let p = currentParent()
  if p != nil: p.addChild(t)

template uiDivider*() =
  let d = newDivider()
  let p = currentParent()
  if p != nil: p.addChild(d)

template uiSplitter*() =
  let s = newSplitter()
  let p = currentParent()
  if p != nil: p.addChild(s)

template uiNavbar*(logoStr: string, body: untyped) =
  let n = newNavbar(logoStr)
  withParent(n):
    body
  let p = currentParent()
  if p != nil: p.addChild(n)

template uiSidebar*(body: untyped) =
  let s = newSidebar()
  withParent(s):
    body
  let p = currentParent()
  if p != nil: p.addChild(s)

template uiDatePicker*() =
  let dp = newDatePicker()
  let p = currentParent()
  if p != nil: p.addChild(dp)

template uiTimePicker*() =
  let tp = newTimePicker()
  let p = currentParent()
  if p != nil: p.addChild(tp)

template uiColorPicker*() =
  let cp = newColorPicker()
  let p = currentParent()
  if p != nil: p.addChild(cp)

template uiFilePicker*() =
  let fp = newFilePicker()
  let p = currentParent()
  if p != nil: p.addChild(fp)

template uiBreadcrumbs*(items: seq[string]) =
  let b = newBreadcrumbs(items)
  let p = currentParent()
  if p != nil: p.addChild(b)

template uiPagination*(count: int) =
  let pg = newPagination(count)
  let p = currentParent()
  if p != nil: p.addChild(pg)

template uiSkeleton*() =
  let sk = newSkeleton()
  let p = currentParent()
  if p != nil: p.addChild(sk)

template uiSteps*(items: seq[string]) =
  let st = newSteps(items)
  let p = currentParent()
  if p != nil: p.addChild(st)

template uiTimeline*() =
  let tl = newTimeline()
  let p = currentParent()
  if p != nil: p.addChild(tl)

template uiTagInput*() =
  let ti = newTagInput()
  let p = currentParent()
  if p != nil: p.addChild(ti)

template uiCarousel*() =
  let c = newCarousel()
  let p = currentParent()
  if p != nil: p.addChild(c)

template uiPopOver*(body: untyped) =
  let po = newPopOver()
  withParent(po):
    body
  let p = currentParent()
  if p != nil: p.addChild(po)

template uiTooltip*(textStr: string) =
  let t = newTooltip(textStr)
  let p = currentParent()
  if p != nil: p.addChild(t)

template uiToast*(msgStr: string) =
  let t = newToast(msgStr)
  let p = currentParent()
  if p != nil: p.addChild(t)

template uiNotification*(msgStr: string) =
  let n = newNotification(msgStr)
  let p = currentParent()
  if p != nil: p.addChild(n)

template uiModal*(titleStr: string, body: untyped) =
  let m = newModal(titleStr)
  withParent(m):
    body
  let p = currentParent()
  if p != nil: p.addChild(m)

template uiDrawer*(body: untyped) =
  let d = newDrawer()
  withParent(d):
    body
  let p = currentParent()
  if p != nil: p.addChild(d)
