import core, theme, textedit, pixie, vmath, layout, strutils, tables, times, sets

# --- Internal Helpers ---

proc findNodeByClass*(w: Widget, cls: string): SvgNode =
  proc findRec(n: SvgNode, c: string): SvgNode =
    if n == nil: return nil
    if c in n.metadata.getOrDefault("class", "").splitWhitespace(): return n
    if n of SvgGroup: (for child in SvgGroup(n).children: (let found = findRec(child, c); if found != nil: return found))
    return nil
  return findRec(w.node, cls)

proc findWidgetByClass*(w: Widget, cls: string): Widget =
  for child in w.children:
    if cls in child.classes: return child
    let found = findWidgetByClass(child, cls)
    if found != nil: return found
  return nil

proc setTextOfClass*(w: Widget, cls, text: string) =
  let n = w.findNodeByClass(cls)
  if n != nil and n of SvgText: SvgText(n).text = text

# --- Widget Base Logic ---

type
  Button* = ref object of Widget
    onClicked*: proc() {.gcsafe.}

  Checkbox* = ref object of Widget
    checked*: bool
    onToggled*: proc(c: bool) {.gcsafe.}

  Slider* = ref object of Widget
    value*: float32
    onChanged*: proc(v: float32) {.gcsafe.}

  Rating* = ref object of Widget
    stars*: int
    onChanged*: proc(s: int) {.gcsafe.}

  Tabs* = ref object of Widget
    index*: int
    onChanged*: proc(i: int) {.gcsafe.}

  ComboBox* = ref object of Widget
    options*: seq[string]
    index*: int
    onChanged*: proc(i: int) {.gcsafe.}

  DataGrid* = ref object of Widget
    headers*: seq[string]
    rows*: seq[seq[string]]

  TreeItem* = ref object of Widget
    expanded*: bool
    label*: string

  DatePickerWidget* = ref object of Widget
    day*, month*, year*: int

  CarouselWidget* = ref object of Widget
    index*: int

  RangeSliderWidget* = ref object of Widget
    valMin*, valMax*: float32

# --- 1. Interactive Widgets ---

proc refresh*(b: Button) = discard

proc newButton*(title: string, onClick: proc() {.gcsafe.} = nil): Button =
  result = Button(createWidgetFromTemplate("pushbutton"))
  result.setTextOfClass("title", title); result.onClicked = onClick
  result.onEvent = proc(w: Widget, ev: GuiEvent): bool =
    let b = Button(w)
    case ev.kind
    of evMouseDown: w.addClass("pressed"); applyStyles(w); return true
    of evMouseUp:
      let was = "pressed" in w.classes
      w.removeClass("pressed"); applyStyles(w)
      if was and b.onClicked != nil: b.onClicked(); return true
    of evMouseEnter: w.addClass("hovered"); applyStyles(w); return true
    of evMouseLeave: w.removeClass("hovered"); w.removeClass("pressed"); applyStyles(w); return true
    else: discard
    return false

proc refresh*(c: Checkbox) =
  if c.checked: c.addClass("checked") else: c.removeClass("checked")
  applyStyles(c)

proc newCheckbox*(label: string, checked: bool = false): Checkbox =
  result = Checkbox(createWidgetFromTemplate("checkbox"))
  result.checked = checked; result.setTextOfClass("label", label); result.refresh()
  result.onEvent = proc(w: Widget, ev: GuiEvent): bool =
    if ev.kind == evClick:
      let c = Checkbox(w); c.checked = not c.checked; c.refresh()
      if c.onToggled != nil: c.onToggled(c.checked); return true
    return false

proc newSwitch*(label: string, checked: bool = false): Checkbox =
  result = newCheckbox(label, checked); result.addClass("switch")

proc newRadio*(label: string, checked: bool = false): Checkbox =
  result = Checkbox(createWidgetFromTemplate("radio"))
  result.checked = checked; result.setTextOfClass("label", label); result.refresh()
  result.onEvent = proc(w: Widget, ev: GuiEvent): bool =
    if ev.kind == evClick:
        let r = Checkbox(w)
        if not r.checked:
            if r.parent != nil:
                for child in r.parent.children:
                    if child of Checkbox and "radio" in child.classes: (let other = Checkbox(child); other.checked = false; other.refresh())
            r.checked = true; r.refresh()
        return true
    return false

proc refresh*(s: Slider) =
  let h = s.findNodeByClass("handle-container")
  if h != nil: h.metadata["transform"] = "translate(" & $(s.value * s.computedRect.w) & " 0)"

proc newSlider*(value: float32 = 0.5): Slider =
  result = Slider(createWidgetFromTemplate("slider")); result.value = value
  result.onEvent = proc(w: Widget, ev: GuiEvent): bool =
    let s = Slider(w)
    if ev.kind == evMouseDown or (ev.kind == evMouseMove and "pressed" in w.classes):
      s.value = clamp((ev.pos.x - w.computedRect.x) / w.computedRect.w, 0.0, 1.0)
      s.refresh()
      if ev.kind == evMouseDown: w.addClass("pressed")
      if s.onChanged != nil: s.onChanged(s.value)
      return true
    elif ev.kind == evMouseUp: w.removeClass("pressed"); return true
    return false

proc newRangeSlider*(vMin, vMax: float32): RangeSliderWidget =
    result = RangeSliderWidget(createWidgetFromTemplate("slider"))
    result.valMin = vMin; result.valMax = vMax; result.addClass("range-slider")
    let h2 = deepClone(result.findNodeByClass("handle-container"))
    if h2 != nil: result.node.children.add(h2)

proc refresh*(r: Rating) =
  for i, child in r.children:
    if i < r.stars: child.addClass("active") else: child.removeClass("active")
    applyStyles(child)

proc newRating*(stars: int = 0): Rating =
  result = Rating(createWidgetFromTemplate("rating")); result.stars = stars; result.attributes["layout"] = "flex"
  for i in 1..5:
    let idx = i
    let star = newButton("*", proc() = (let r = result; r.stars = idx; r.refresh(); if r.onChanged != nil: r.onChanged(idx)))
    result.addChild(star)
  result.refresh()

proc newComboBox*(options: seq[string]): ComboBox =
  result = ComboBox(createWidgetFromTemplate("combobox")); result.options = options
  if options.len > 0: result.setTextOfClass("current-text", options[0])
  result.onEvent = proc(w: Widget, ev: GuiEvent): bool =
    if ev.kind == evClick:
      let cb = ComboBox(w); let win = w.window()
      if win != nil:
        let menu = newWidget(); menu.addClass("menu"); menu.attributes["layout"] = "flex"; menu.attributes["flex-direction"] = "column"
        for i, opt in cb.options:
          let idx = i; let btn = newButton(opt, proc() = (cb.index = idx; cb.setTextOfClass("current-text", cb.options[idx]); win.overlays.setLen(0); if cb.onChanged != nil: cb.onChanged(idx)))
          menu.addChild(btn)
        menu.computedRect = rect(w.computedRect.x, w.computedRect.y + w.computedRect.h, w.computedRect.w, menu.children.len.float32 * 32f32)
        win.overlays.add(menu)
      return true
    return false

# --- 2. Text Widgets ---

type TextBox* = ref object of Widget
  editor*: TextEditor
  onChanged*: proc(s: string) {.gcsafe.}

proc newTextBox*(text: string = ""): TextBox =
  result = TextBox(createWidgetFromTemplate("textbox")); result.editor = newTextEditor(); result.editor.setText(text)
  result.setTextOfClass("content", text)
  result.onEvent = proc(w: Widget, ev: GuiEvent): bool =
    let tb = TextBox(w)
    case ev.kind
    of evClick: w.window().focusWidget(w); return true
    of evKeyDown:
      if w.window() != nil and w.window().focusedWidget == w:
        tb.editor.handleKey(ev.key, ev.mods); tb.setTextOfClass("content", tb.editor.text)
        if tb.onChanged != nil: tb.onChanged(tb.editor.text); return true
    of evTextInput:
      if w.window() != nil and w.window().focusedWidget == w:
        tb.editor.insert(ev.text); tb.setTextOfClass("content", tb.editor.text)
        if tb.onChanged != nil: tb.onChanged(tb.editor.text); return true
    else: discard
    return false

proc newSearchInput*(text: string = ""): TextBox = (result = newTextBox(text); result.addClass("search-input"))
proc newPasswordInput*(text: string = ""): TextBox = (result = newTextBox(text); result.addClass("password-input"))

# --- 3. Lists & Data ---

proc newDataGrid*(headers: seq[string], data: seq[seq[string]]): DataGrid =
  result = DataGrid(createWidgetFromTemplate("datagrid")); result.headers = headers; result.rows = data
  let hr = result.findWidgetByClass("header-row"); let rcont = result.findWidgetByClass("rows")
  if hr != nil: (for h in headers: (let l = newLabel(h); l.attributes["width"] = "120"; hr.addChild(l)))
  if rcont != nil: (for row in data: (let rw = newWidget(); rw.addClass("row"); rw.attributes["layout"] = "flex"; for cell in row: (let l = newLabel(cell); l.attributes["width"] = "120"; rw.addChild(l)); rcont.addChild(rw)))

proc newTreeItem*(label: string): TreeItem =
  result = TreeItem(createWidgetFromTemplate("tree-item")); result.setTextOfClass("label", label)
  result.onEvent = proc(w: Widget, ev: GuiEvent): bool =
    if ev.kind == evClick: (let ti = TreeItem(w); ti.expanded = not ti.expanded; if ti.expanded: w.addClass("expanded") else: w.removeClass("expanded"); applyStyles(w); return true)
    return false

# --- 4. Navigation ---

proc newBreadcrumbs*(items: seq[string]): Widget =
  result = newWidget(); result.addClass("breadcrumbs"); result.attributes["layout"] = "flex"
  for i, s in items: (result.addChild(newButton(s)); if i < items.len - 1: result.addChild(newLabel("/")))

proc newTabs*(titles: seq[string]): Tabs =
  result = Tabs(newWidget()); result.addClass("tabs"); result.attributes["layout"] = "flex"
  for i, t in titles: (let idx = i; result.addChild(newButton(t, proc() = (let r = result; r.index = idx; if r.onChanged != nil: r.onChanged(idx)))))

# --- 5. Containers ---

type Card* = ref object of Widget
proc newCard*(title: string, body: Widget): Card =
  result = Card(createWidgetFromTemplate("card"))
  let h = result.findWidgetByClass("header"); if h != nil: h.addChild(newLabel(title))
  let b = result.findWidgetByClass("body"); if b != nil: b.addChild(body)

type Accordion* = ref object of Widget
  expanded*: bool
proc newAccordion*(title: string, body: Widget): Accordion =
  result = Accordion(createWidgetFromTemplate("card")); result.addClass("accordion")
  let h = result.findWidgetByClass("header")
  if h != nil: (h.addChild(newButton(title, proc() = (let a = Accordion(result); a.expanded = not a.expanded; let b = result.findWidgetByClass("body"); if b != nil: b.visible = a.expanded))))
  let b = result.findWidgetByClass("body"); if b != nil: (b.addChild(body); b.visible = false)

type Modal* = ref object of Widget
proc newModal*(title: string, body: Widget): Modal =
  result = Modal(createWidgetFromTemplate("card")); result.addClass("modal")
  let h = result.findWidgetByClass("header"); if h != nil: h.addChild(newLabel(title))
  let b = result.findWidgetByClass("body"); if b != nil: b.addChild(body)

# --- 6. Simple / Misc ---

proc newProgressBar*(p: float32 = 0.0): Widget =
  result = createWidgetFromTemplate("progressbar")
  let f = result.findNodeByClass("fill"); if f != nil and f of SvgRect: SvgRect(f).width = p * 200

proc newBadge*(val: string): Widget = (result = createWidgetFromTemplate("badge"); result.setTextOfClass("label", val))
proc newTag*(label: string): Widget = (result = createWidgetFromTemplate("badge"); result.addClass("tag"); result.setTextOfClass("label", label))
proc newAvatar*(initials: string): Widget = (result = createWidgetFromTemplate("avatar"); result.setTextOfClass("initials", initials))
proc newSpinner*(): Widget = createWidgetFromTemplate("spinner")
proc newDivider*(): Widget = createWidgetFromTemplate("divider")
proc newSkeleton*(): Widget = (result = newWidget(newSvgRect()); result.addClass("skeleton"); result.attributes["width"] = "100"; result.attributes["height"] = "20")
proc newNavbar*(logo: string): Widget = (result = createWidgetFromTemplate("navbar"); result.setTextOfClass("logo", logo))
proc newSidebar*(): Widget = createWidgetFromTemplate("sidebar")
proc newScrollArea*(c: Widget): Widget = (result = createWidgetFromTemplate("scrollarea"); let v = result.findWidgetByClass("viewport"); if v != nil: v.addChild(c); result)
proc newDatePicker*(): DatePickerWidget =
    result = DatePickerWidget(createWidgetFromTemplate("datepicker"))
    let grid = result.findWidgetByClass("grid")
    if grid != nil:
        grid.attributes["layout"] = "flex"; grid.attributes["flex-direction"] = "column"
        for r in 0..4:
            let row = newWidget(); row.attributes["layout"] = "flex"
            for c in 1..7: row.addChild(newButton($(r*7+c)))
            grid.addChild(row)

proc newColorPicker*(): Widget = createWidgetFromTemplate("color-picker")
proc newCarousel*(items: seq[Widget]): CarouselWidget = (result = CarouselWidget(createWidgetFromTemplate("carousel")); let cont = result.findWidgetByClass("items"); if cont != nil: (for it in items: cont.addChild(it)); result)
proc newListView*(): Widget = (result = newWidget(); result.addClass("list-view"); result.attributes["layout"] = "flex"; result.attributes["flex-direction"] = "column")
proc newPagination*(c: int): Widget = (result = newWidget(); result.addClass("pagination"); result.attributes["layout"] = "flex"; result.addChild(newButton("<")); (for i in 1..c: result.addChild(newButton($i))); result.addChild(newButton(">")))
proc newSteps*(s: seq[string]): Widget = (result = newWidget(); result.addClass("steps"); result.attributes["layout"] = "flex"; for x in s: result.addChild(newButton(x)))
proc newTimeline*(s: seq[string]): Widget = (result = newWidget(); result.addClass("timeline"); result.attributes["layout"] = "flex"; result.attributes["flex-direction"] = "column"; for x in s: result.addChild(newLabel("• " & x)))
proc newPopOver*(c: Widget): Widget = (result = createWidgetFromTemplate("popover"); let cont = result.findWidgetByClass("content"); if cont != nil: cont.addChild(c); result)
proc newTooltip*(t: string): Widget = (result = createWidgetFromTemplate("popover"); result.addClass("tooltip"); result.addChild(newLabel(t)))
proc newToast*(m: string): Widget = (result = createWidgetFromTemplate("badge"); result.addClass("toast"); result.setTextOfClass("label", m))
proc newNotification*(m: string): Widget = (result = newToast(m); result.addClass("notification"))
proc newDrawer*(c: Widget): Widget = (result = newWidget(); result.addClass("drawer"); result.addChild(c))
proc newMenuBar*(): Widget = (result = newWidget(); result.addClass("menubar"); result.attributes["height"] = "32"; result.attributes["layout"] = "flex")
proc newSplitter*(): Widget = (result = newWidget(newSvgRect()); result.addClass("splitter"); result.attributes["width"] = "4")
proc newTagInput*(): Widget = (result = newWidget(); result.addClass("tag-input"); result.attributes["layout"] = "flex"; result.addChild(newTag("Nim")); result.addChild(newTextBox("")))
proc newTimePicker*(): Widget = (result = newWidget(); result.addClass("time-picker"); result.addChild(newLabel("12:00")))
proc newButtonGroup*(titles: seq[string]): Widget = (result = newWidget(); result.addClass("button-group"); result.attributes["layout"] = "flex"; for t in titles: result.addChild(newButton(t)))
proc newFilePicker*(): Widget = (result = newWidget(); result.addClass("file-picker"); result.attributes["layout"] = "flex"; let btn = newButton("Select File..."); result.addChild(btn); result.addChild(newLabel("No file selected")))
