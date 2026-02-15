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

# --- 1. Basic Widgets ---

proc newLabel*(text: string): Widget =
  let t = newSvgText(); t.text = text; result = newWidget(t); result.addClass("label")

type Button* = ref object of Widget
  onClicked*: proc() {.gcsafe.}
proc newButton*(title: string, onClick: proc() {.gcsafe.} = nil): Button =
  result = Button(createWidgetFromTemplate("pushbutton"))
  result.setTextOfClass("title", title); result.onClicked = onClick
  result.onEvent = proc(w: Widget, ev: GuiEvent): bool =
    let b = Button(w)
    case ev.kind
    of evMouseDown: w.addClass("pressed"); applyStyles(w); return true
    of evMouseUp: (let was = "pressed" in w.classes; w.removeClass("pressed"); applyStyles(w); if was and b.onClicked != nil: b.onClicked(); return true)
    of evMouseEnter: w.addClass("hovered"); applyStyles(w); return true
    of evMouseLeave: w.removeClass("hovered"); w.removeClass("pressed"); applyStyles(w); return true
    else: discard
    return false

type Checkbox* = ref object of Widget
  checked*: bool
  onToggled*: proc(c: bool) {.gcsafe.}
proc initCheckbox(cb: Checkbox, label: string, checked: bool) =
  cb.checked = checked; cb.setTextOfClass("label", label)
  if checked: cb.addClass("checked")
  cb.onEvent = proc(w: Widget, ev: GuiEvent): bool =
    let c = Checkbox(w)
    if ev.kind == evClick: (c.checked = not c.checked; if c.checked: w.addClass("checked") else: w.removeClass("checked"); applyStyles(w); if c.onToggled != nil: c.onToggled(c.checked); return true)
    return false

proc newCheckbox*(label: string, checked: bool = false): Checkbox = (result = Checkbox(createWidgetFromTemplate("checkbox")); initCheckbox(result, label, checked))
proc newSwitch*(label: string, checked: bool = false): Checkbox = (result = Checkbox(createWidgetFromTemplate("checkbox")); initCheckbox(result, label, checked); result.addClass("switch"))

type Radio* = ref object of Checkbox
proc newRadio*(label: string, checked: bool = false): Radio =
  result = Radio(createWidgetFromTemplate("radio"))
  initCheckbox(result, label, checked)

type Slider* = ref object of Widget
  value*: float32
  onChanged*: proc(v: float32) {.gcsafe.}
proc newSlider*(value: float32 = 0.5): Slider =
  result = Slider(createWidgetFromTemplate("slider")); result.value = value
  result.onEvent = proc(w: Widget, ev: GuiEvent): bool =
    let s = Slider(w)
    if ev.kind == evMouseDown or (ev.kind == evMouseMove and "pressed" in w.classes):
      s.value = clamp((ev.pos.x - w.computedRect.x) / w.computedRect.w, 0.0, 1.0)
      let h = s.findNodeByClass("handle-container"); if h != nil: h.metadata["transform"] = "translate(" & $(s.value * w.computedRect.w) & " 0)"
      if ev.kind == evMouseDown: w.addClass("pressed")
      if s.onChanged != nil: s.onChanged(s.value)
      return true
    elif ev.kind == evMouseUp: w.removeClass("pressed"); return true
    return false

type RangeSlider* = ref object of Widget
  valMin*, valMax*: float32
proc newRangeSlider*(vMin: float32 = 0.2, vMax: float32 = 0.8): RangeSlider =
  result = RangeSlider(createWidgetFromTemplate("slider")); result.valMin = vMin; result.valMax = vMax
  result.addClass("range-slider")
  # Add second handle
  let h2 = result.findNodeByClass("handle-container")
  if h2 != nil: result.node.children.add(deepClone(h2))

type ProgressBar* = ref object of Widget
  progress*: float32
proc newProgressBar*(p: float32 = 0.0): ProgressBar =
  result = ProgressBar(createWidgetFromTemplate("progressbar")); result.progress = p
  let f = result.findNodeByClass("fill"); if f != nil and f of SvgRect: SvgRect(f).width = p * 200

type Spinner* = ref object of Widget
proc newSpinner*(): Spinner = result = Spinner(createWidgetFromTemplate("spinner"))

# --- 2. Text Inputs ---

type TextBox* = ref object of Widget
  editor*: TextEditor
  onChanged*: proc(s: string) {.gcsafe.}
proc newTextBox*(text: string = ""): TextBox =
  result = TextBox(createWidgetFromTemplate("textbox")); result.editor = newTextEditor(); result.editor.setText(text)
  result.onEvent = proc(w: Widget, ev: GuiEvent): bool =
    let tb = TextBox(w)
    case ev.kind
    of evClick: w.window.focusWidget(w); return true
    of evKeyDown: (if w.window != nil and w.window.focusedWidget == w: (tb.editor.handleKey(ev.key, ev.mods); tb.setTextOfClass("content", tb.editor.text); if tb.onChanged != nil: tb.onChanged(tb.editor.text); return true))
    of evTextInput: (if w.window != nil and w.window.focusedWidget == w: (tb.editor.insert(ev.text); tb.setTextOfClass("content", tb.editor.text); if tb.onChanged != nil: tb.onChanged(tb.editor.text); return true))
    else: discard
    return false

type SearchInput* = ref object of TextBox
proc newSearchInput*(text: string = ""): SearchInput =
    result = SearchInput(newTextBox(text)); result.addClass("search-input")

type PasswordInput* = ref object of TextBox
proc newPasswordInput*(text: string = ""): PasswordInput =
    result = PasswordInput(newTextBox(text)); result.addClass("password-input")

# --- 3. Complex Selection & Pickers ---

type Menu* = ref object of Widget
proc newMenu*(): Menu =
  result = Menu(newWidget(newSvgGroup()))
  result.addClass("menu"); result.attributes["layout"] = "flex"; result.attributes["flex-direction"] = "column"; result.attributes["width"] = "200"

proc addMenuItem*(m: Menu, label: string, onClick: proc() {.gcsafe.}) =
  let btn = newButton(label, onClick); btn.addClass("menu-item"); m.addChild(btn)

type ComboBox* = ref object of Widget
  options*: seq[string]; index*: int
proc newComboBox*(options: seq[string]): ComboBox =
  result = ComboBox(createWidgetFromTemplate("combobox")); result.options = options
  if options.len > 0: result.setTextOfClass("current-text", options[0])
  result.onEvent = proc(w: Widget, ev: GuiEvent): bool =
    if ev.kind == evClick:
      let cb = ComboBox(w)
      if w.window != nil:
        let menu = newMenu()
        for i, opt in cb.options:
          let idx = i
          menu.addMenuItem(opt, proc() = (cb.index = idx; cb.setTextOfClass("current-text", cb.options[idx]); w.window.overlays.setLen(0)))
        menu.computedRect = rect(w.computedRect.x, w.computedRect.y + w.computedRect.h, 200, menu.children.len.float32 * 40f32)
        w.window.overlays.add(menu)
      return true
    return false

type DatePicker* = ref object of Widget
proc newDatePicker*(): DatePicker =
  result = DatePicker(createWidgetFromTemplate("datepicker"))
  let grid = result.findWidgetByClass("grid")
  if grid != nil:
    grid.attributes["layout"] = "flex"; grid.attributes["flex-direction"] = "column"
    for r in 0..4:
      let row = newWidget(); row.attributes["layout"] = "flex"; row.attributes["flex-direction"] = "row"
      for c in 1..7:
        let day = newButton($(r * 7 + c)); day.attributes["width"] = "32"; day.attributes["height"] = "32"; row.addChild(day)
      grid.addChild(row)

type TimePicker* = ref object of Widget
proc newTimePicker*(): TimePicker =
    result = TimePicker(newWidget()); result.addClass("time-picker"); result.attributes["layout"] = "flex"
    result.addChild(newButton("12")); result.addChild(newLabel(":")); result.addChild(newButton("00"))

type ColorPicker* = ref object of Widget
proc newColorPicker*(): ColorPicker =
    result = ColorPicker(createWidgetFromTemplate("color-picker"))
    result.onEvent = proc(w: Widget, ev: GuiEvent): bool =
        if ev.kind == evMouseDown or (ev.kind == evMouseMove and "pressed" in w.classes):
            w.addClass("pressed")
            # Set color based on pos... simplified
            return true
        elif ev.kind == evMouseUp: w.removeClass("pressed"); return true
        return false

type Rating* = ref object of Widget
  stars*: int
proc newRating*(s: int = 0): Rating =
  result = Rating(createWidgetFromTemplate("rating")); result.stars = s; result.attributes["layout"] = "flex"
  for i in 1..5:
    let star = newButton("*", proc() = (result.stars = i; echo "Rated: ", i))
    star.addClass(if i <= s: "active" else: "inactive"); result.addChild(star)

# --- 4. Information Display ---

type Badge* = ref object of Widget
proc newBadge*(val: string): Badge =
  result = Badge(createWidgetFromTemplate("badge")); result.setTextOfClass("label", val)

type Tag* = ref object of Widget
proc newTag*(label: string): Tag =
  result = Tag(createWidgetFromTemplate("badge")); result.addClass("tag"); result.setTextOfClass("label", label)

type TagInput* = ref object of Widget
proc newTagInput*(): TagInput =
  result = TagInput(newWidget()); result.addClass("tag-input"); result.attributes["layout"] = "flex"
  result.addChild(newTag("Nim")); result.addChild(newTextBox(""))

type Avatar* = ref object of Widget
proc newAvatar*(i: string): Avatar =
  result = Avatar(createWidgetFromTemplate("avatar")); result.setTextOfClass("initials", i)

type Tooltip* = ref object of Widget
proc newTooltip*(t: string): Tooltip =
  result = Tooltip(createWidgetFromTemplate("popover")); result.addClass("tooltip"); result.addChild(newLabel(t))

type PopOver* = ref object of Widget
proc newPopOver*(content: Widget): PopOver =
    result = PopOver(createWidgetFromTemplate("popover")); result.addChild(content)

type Modal* = ref object of Widget
proc newModal*(t: string, body: Widget): Modal =
  result = Modal(createWidgetFromTemplate("card")); result.addClass("modal")
  let h = result.findWidgetByClass("header"); if h != nil: h.addChild(newLabel(t))
  let b = result.findWidgetByClass("body"); if b != nil: b.addChild(body)

type Toast* = ref object of Widget
proc newToast*(m: string): Toast =
    result = Toast(createWidgetFromTemplate("badge")); result.addClass("toast"); result.setTextOfClass("label", m)

type Notification* = ref object of Toast
proc newNotification*(m: string): Notification = result = Notification(newToast(m)); result.addClass("notification")

type Drawer* = ref object of Widget
proc newDrawer*(body: Widget): Drawer =
    result = Drawer(newWidget()); result.addClass("drawer"); result.addChild(body)

# --- 5. Navigation & Lists ---

type TreeItem* = ref object of Widget
  expanded*: bool
proc newTreeItem*(label: string): TreeItem =
  result = TreeItem(createWidgetFromTemplate("tree-item")); result.setTextOfClass("label", label)
  result.onEvent = proc(w: Widget, ev: GuiEvent): bool =
    if ev.kind == evClick: (let ti = TreeItem(w); ti.expanded = not ti.expanded; if ti.expanded: w.addClass("expanded") else: w.removeClass("expanded"); applyStyles(w); return true)
    return false

type ListView* = ref object of Widget
proc newListView*(): ListView = (result = ListView(newWidget()); result.addClass("list-view"); result.attributes["layout"] = "flex"; result.attributes["flex-direction"] = "column")

type DataGrid* = ref object of Widget
proc newDataGrid*(headers: seq[string], data: seq[seq[string]]): DataGrid =
  result = DataGrid(createWidgetFromTemplate("datagrid"))
  let hr = result.findWidgetByClass("header-row"); let rows = result.findWidgetByClass("rows")
  if hr != nil: (for h in headers: (let lbl = newLabel(h); lbl.attributes["width"] = "100"; hr.addChild(lbl)))
  if rows != nil:
    for row in data:
      let rw = newWidget(); rw.addClass("row"); rw.attributes["layout"] = "flex"; rw.attributes["flex-direction"] = "row"
      for cell in row: (let lbl = newLabel(cell); lbl.attributes["width"] = "100"; rw.addChild(lbl))
      rows.addChild(rw)

type Breadcrumbs* = ref object of Widget
proc newBreadcrumbs*(it: seq[string]): Breadcrumbs =
  result = Breadcrumbs(newWidget()); result.addClass("breadcrumbs"); result.attributes["layout"] = "flex"
  for i, s in it: (result.addChild(newButton(s)); if i < it.len - 1: result.addChild(newLabel("/")))

type Pagination* = ref object of Widget
proc newPagination*(count: int): Pagination =
  result = Pagination(newWidget()); result.addClass("pagination"); result.attributes["layout"] = "flex"
  result.addChild(newButton("<")); (for i in 1..count: result.addChild(newButton($i))); result.addChild(newButton(">"))

type Steps* = ref object of Widget
proc newSteps*(it: seq[string]): Steps =
  result = Steps(newWidget()); result.addClass("steps"); result.attributes["layout"] = "flex"
  for i, s in it: result.addChild(newButton(s))

type Timeline* = ref object of Widget
proc newTimeline*(it: seq[string]): Timeline =
  result = Timeline(newWidget()); result.addClass("timeline"); result.attributes["layout"] = "flex"; result.attributes["flex-direction"] = "column"
  for s in it: result.addChild(newLabel("• " & s))

type Tabs* = ref object of Widget
  onTabChanged*: proc(i: int) {.gcsafe.}
proc newTabs*(it: seq[string]): Tabs =
  result = Tabs(newWidget()); result.addClass("tabs"); result.attributes["layout"] = "flex"
  for i, s in it: (let idx = i; result.addChild(newButton(s, proc() = (if result.onTabChanged != nil: result.onTabChanged(idx)))))

# --- 6. Containers & Layout ---

type Accordion* = ref object of Widget
  expanded*: bool
proc newAccordion*(t: string, body: Widget): Accordion =
  result = Accordion(createWidgetFromTemplate("card")); result.addClass("accordion")
  let h = result.findWidgetByClass("header"); if h != nil: h.addChild(newButton(t, proc() = (let a = Accordion(result); a.expanded = not a.expanded; let b = result.findWidgetByClass("body"); if b != nil: b.visible = a.expanded)))
  let b = result.findWidgetByClass("body"); if b != nil: (b.addChild(body); b.visible = false)

type Card* = ref object of Widget
proc newCard*(t: string, body: Widget): Card =
  result = Card(createWidgetFromTemplate("card"))
  let h = result.findWidgetByClass("header"); if h != nil: h.addChild(newLabel(t))
  let b = result.findWidgetByClass("body"); if b != nil: b.addChild(body)

type ScrollArea* = ref object of Widget
proc newScrollArea*(c: Widget): ScrollArea =
    result = ScrollArea(createWidgetFromTemplate("scrollarea"))
    let v = result.findWidgetByClass("viewport"); if v != nil: v.addChild(c)

type Navbar* = ref object of Widget
proc newNavbar*(l: string): Navbar =
  result = Navbar(createWidgetFromTemplate("navbar")); result.setTextOfClass("logo", l)

type Sidebar* = ref object of Widget
proc newSidebar*(): Sidebar = result = Sidebar(createWidgetFromTemplate("sidebar"))

type MenuBar* = ref object of Widget
proc newMenuBar*(): MenuBar = (result = MenuBar(newWidget()); result.addClass("menubar"); result.attributes["layout"] = "flex"; result.attributes["height"] = "32")

type Divider* = ref object of Widget
proc newDivider*(): Divider = result = Divider(createWidgetFromTemplate("divider"))

type Splitter* = ref object of Widget
proc newSplitter*(): Splitter = result = Splitter(createWidgetFromTemplate("divider")); result.addClass("splitter")

type Skeleton* = ref object of Widget
proc newSkeleton*(): Skeleton = result = Skeleton(newWidget(newSvgRect())); result.addClass("skeleton"); result.attributes["width"] = "100"; result.attributes["height"] = "20"

type Carousel* = ref object of Widget
  index*: int
proc newCarousel*(items: seq[Widget]): Carousel =
  result = Carousel(createWidgetFromTemplate("carousel")); let itNode = result.findWidgetByClass("items")
  if itNode != nil: (for it in items: itNode.addChild(it))
  result.onEvent = proc(w: Widget, ev: GuiEvent): bool =
    if ev.kind == evClick: (let c = Carousel(w); c.index = (c.index + 1) mod items.len; return true)
    return false
