import core, theme, textedit, pixie, vmath, layout, strutils, tables, times, sets

# --- Group 1: Basic Interaction ---

type
  Button* = ref object of Widget
    onClicked*: proc() {.gcsafe.}

proc newButton*(title: string): Button =
  result = Button(newWidget(newSvgGroup()))
  result.addClass("pushbutton")
  let label = newWidget(newSvgText())
  SvgText(label.node).text = title
  result.addChild(label)
  result.onEvent = proc(w: Widget, ev: GuiEvent): bool =
    let b = Button(w)
    case ev.kind
    of evMouseDown: w.addClass("pressed"); return true
    of evMouseUp:
      w.removeClass("pressed")
      if b.onClicked != nil: b.onClicked()
      return true
    of evMouseEnter: w.addClass("hovered"); return true
    of evMouseLeave: w.removeClass("hovered"); w.removeClass("pressed"); return true
    else: discard
    return false

type
  Checkbox* = ref object of Widget
    checked*: bool
    onToggled*: proc(checked: bool) {.gcsafe.}

proc newCheckbox*(checked: bool = false): Checkbox =
  result = Checkbox(checked: checked)
  result.node = newSvgGroup()
  result.addClass("checkbox")
  if checked: result.addClass("checked")
  result.onEvent = proc(w: Widget, ev: GuiEvent): bool =
    let cb = Checkbox(w)
    if ev.kind == evMouseUp:
      cb.checked = not cb.checked
      if cb.checked: w.addClass("checked") else: w.removeClass("checked")
      if cb.onToggled != nil: cb.onToggled(cb.checked)
      return true
    return false

type
  Radio* = ref object of Widget
    selected*: bool
    onSelected*: proc() {.gcsafe.}

proc newRadio*(selected: bool = false): Radio =
  result = Radio(selected: selected)
  result.node = newSvgGroup()
  result.addClass("radio")
  if selected: result.addClass("selected")
  result.onEvent = proc(w: Widget, ev: GuiEvent): bool =
    let r = Radio(w)
    if ev.kind == evMouseUp:
      r.selected = true
      w.addClass("selected")
      if r.onSelected != nil: r.onSelected()
      return true
    return false

type
  Toggle* = ref object of Widget
    on*: bool
    onToggled*: proc(on: bool) {.gcsafe.}

proc newToggle*(on: bool = false): Toggle =
  result = Toggle(on: on)
  result.node = newSvgGroup()
  result.addClass("toggle")
  if on: result.addClass("on")
  result.onEvent = proc(w: Widget, ev: GuiEvent): bool =
    let t = Toggle(w)
    if ev.kind == evMouseUp:
      t.on = not t.on
      if t.on: w.addClass("on") else: w.removeClass("on")
      if t.onToggled != nil: t.onToggled(t.on)
      return true
    return false

# --- Group 2: Values & Progress ---

type
  Slider* = ref object of Widget
    value*: float32
    onChanged*: proc(v: float32) {.gcsafe.}

proc newSlider*(v: float32 = 0.0): Slider =
  result = Slider(value: v)
  result.node = newSvgGroup()
  result.addClass("slider")
  result.onEvent = proc(w: Widget, ev: GuiEvent): bool =
    let s = Slider(w)
    if ev.kind == evMouseMove and w.gui.pressedWidget == w:
      s.value = clamp(ev.pos.x / w.computedRect.w, 0.0, 1.0)
      if s.onChanged != nil: s.onChanged(s.value)
      return true
    return false

type
  RangeSlider* = ref object of Widget
    minVal*, maxVal*: float32
    onChanged*: proc(min, max: float32) {.gcsafe.}

proc newRangeSlider*(min, max: float32): RangeSlider =
  result = RangeSlider(minVal: min, maxVal: max)
  result.node = newSvgGroup()
  result.addClass("range-slider")

type
  ProgressBar* = ref object of Widget
    progress*: float32

proc newProgressBar*(p: float32 = 0.0): ProgressBar =
  result = ProgressBar(progress: p)
  result.node = newSvgGroup()
  result.addClass("progressbar")

type
  Spinner* = ref object of Widget
proc newSpinner*(): Spinner =
  result = Spinner()
  result.node = newSvgGroup()
  result.addClass("spinner")

# --- Group 3: Data Visualization ---

type
  ListView* = ref object of Widget
    items*: seq[string]

proc newListView*(items: seq[string]): ListView =
  result = ListView(items: items)
  result.node = newSvgGroup()
  result.addClass("list-view")
  result.layContain = uint32(LAY_COLUMN) or uint32(LAY_FLEX)
  for item in items:
    result.addChild(newButton(item))

type
  TreeView* = ref object of Widget
    label*: string
    isExpanded*: bool

proc newTreeView*(text: string): TreeView =
  result = TreeView(label: text, isExpanded: false)
  result.node = newSvgGroup()
  result.addClass("tree-view")
  result.addChild(newButton(text))
  result.onEvent = proc(w: Widget, ev: GuiEvent): bool =
    let t = TreeView(w)
    if ev.kind == evClick:
      t.isExpanded = not t.isExpanded
      for child in w.children[1..^1]: child.visible = t.isExpanded
      return true
    return false

type
  DataGrid* = ref object of Widget
    columns*: seq[string]
    rows*: seq[seq[string]]

proc newDataGrid*(cols: seq[string], data: seq[seq[seq[string]]]): DataGrid =
  # Fixed types
  discard

proc newDataGrid*(cols: seq[string], data: seq[seq[string]]): DataGrid =
  result = DataGrid(columns: cols, rows: data)
  result.node = newSvgGroup()
  result.addClass("data-grid")
  result.layContain = uint32(LAY_COLUMN) or uint32(LAY_FLEX)
  let header = newWidget(newSvgGroup())
  header.layContain = uint32(LAY_ROW) or uint32(LAY_FLEX)
  for c in cols: header.addChild(newButton(c))
  result.addChild(header)
  for r in data:
    let row = newWidget(newSvgGroup())
    row.layContain = uint32(LAY_ROW) or uint32(LAY_FLEX)
    for cell in r: row.addChild(newWidget(newSvgText(text = cell)))
    result.addChild(row)

# --- Group 4: Advanced Navigation ---

type
  Tabs* = ref object of Widget
    activeIdx*: int
    tabTitles*: seq[string]

proc newTabs*(titles: seq[string]): Tabs =
  result = Tabs(activeIdx: 0, tabTitles: titles)
  result.node = newSvgGroup()
  result.addClass("tabs")
  result.layContain = uint32(LAY_ROW) or uint32(LAY_FLEX)
  for i, t in titles:
    let b = newButton(t)
    let idx = i
    b.onClicked = proc() =
      let p = b.parent
      if p of Tabs: Tabs(p).activeIdx = idx
    result.addChild(b)

type
  Breadcrumbs* = ref object of Widget
proc newBreadcrumbs*(parts: seq[string]): Breadcrumbs =
  result = Breadcrumbs()
  result.node = newSvgGroup()
  result.addClass("breadcrumbs")
  result.layContain = uint32(LAY_ROW) or uint32(LAY_FLEX)
  for p in parts: result.addChild(newButton(p))

type
  Pagination* = ref object of Widget
proc newPagination*(current, total: int): Pagination =
  result = Pagination()
  result.node = newSvgGroup()
  result.addClass("pagination")
  result.layContain = uint32(LAY_ROW) or uint32(LAY_FLEX)
  result.addChild(newButton("Prev"))
  result.addChild(newButton("Next"))

# --- Group 5: Complex Containers ---

type
  Accordion* = ref object of Widget
proc newAccordion*(title: string, content: Widget): Accordion =
  result = Accordion()
  result.node = newSvgGroup()
  result.addClass("accordion")
  let b = newButton(title)
  result.addChild(b)
  result.addChild(content)
  content.visible = false
  b.onClicked = proc() = content.visible = not content.visible

type
  ScrollArea* = ref object of Widget
proc newScrollArea*(content: Widget): ScrollArea =
  result = ScrollArea()
  result.node = newSvgGroup()
  result.addClass("scroll-area")
  result.addChild(content)

type Card* = ref object of Widget
proc newCard*(body: Widget): Card =
  result = Card(); result.node = newSvgGroup(); result.addClass("card"); result.addChild(body)

type Splitter* = ref object of Widget
proc newSplitter*(): Splitter = result = Splitter(); result.node = newSvgGroup(); result.addClass("splitter")

type Drawer* = ref object of Widget
proc newDrawer*(): Drawer = result = Drawer(); result.node = newSvgGroup(); result.addClass("drawer")

# --- Group 6: Overlays & Feedback ---

type Modal* = ref object of Widget
proc newModal*(title: string, body: Widget): Modal =
  result = Modal(); result.node = newSvgGroup(); result.addClass("modal"); result.addChild(newButton(title)); result.addChild(body)

type Dialog* = ref object of Modal
proc newDialog*(title: string, body: Widget): Dialog =
  result = Dialog(); result.node = newSvgGroup(); result.addClass("dialog"); result.addChild(newButton(title)); result.addChild(body)

type Toast* = ref object of Widget
proc newToast*(msg: string): Toast =
  result = Toast(); result.node = newSvgGroup(); result.addClass("toast"); result.addChild(newWidget(newSvgText(text = msg)))

type Notification* = ref object of Widget
proc newNotification*(msg: string): Notification =
  result = Notification(); result.node = newSvgGroup(); result.addClass("notification"); result.addChild(newWidget(newSvgText(text = msg)))

type Tooltip* = ref object of Widget
proc newTooltip*(msg: string): Tooltip =
  result = Tooltip(); result.node = newSvgGroup(); result.addClass("tooltip"); result.addChild(newWidget(newSvgText(text = msg)))

# --- Group 7: Specialized Pickers ---

type DatePicker* = ref object of Widget
proc newDatePicker*(): DatePicker = result = DatePicker(); result.node = newSvgGroup(); result.addClass("date-picker")

type TimePicker* = ref object of Widget
proc newTimePicker*(): TimePicker = result = TimePicker(); result.node = newSvgGroup(); result.addClass("time-picker")

type ColorPicker* = ref object of Widget
proc newColorPicker*(): ColorPicker = result = ColorPicker(); result.node = newSvgGroup(); result.addClass("color-picker")

type FilePicker* = ref object of Widget
proc newFilePicker*(): FilePicker = result = FilePicker(); result.node = newSvgGroup(); result.addClass("file-picker")

type Rating* = ref object of Widget
proc newRating*(): Rating = result = Rating(); result.node = newSvgGroup(); result.addClass("rating")

type TagInput* = ref object of Widget
proc newTagInput*(): TagInput = result = TagInput(); result.node = newSvgGroup(); result.addClass("tag-input")

# --- Group 8: Misc Components ---

type Avatar* = ref object of Widget
proc newAvatar*(): Avatar = result = Avatar(); result.node = newSvgGroup(); result.addClass("avatar")

type Badge* = ref object of Widget
proc newBadge*(text: string): Badge = result = Badge(); result.node = newSvgGroup(); result.addClass("badge"); result.addChild(newWidget(newSvgText(text = text)))

type Skeleton* = ref object of Widget
proc newSkeleton*(): Skeleton = result = Skeleton(); result.node = newSvgGroup(); result.addClass("skeleton")

type Steps* = ref object of Widget
proc newSteps*(): Steps = result = Steps(); result.node = newSvgGroup(); result.addClass("steps")

type Timeline* = ref object of Widget
proc newTimeline*(): Timeline = result = Timeline(); result.node = newSvgGroup(); result.addClass("timeline")

type Carousel* = ref object of Widget
proc newCarousel*(): Carousel = result = Carousel(); result.node = newSvgGroup(); result.addClass("carousel")

type PopOver* = ref object of Widget
proc newPopOver*(): PopOver = result = PopOver(); result.node = newSvgGroup(); result.addClass("popover")

type Divider* = ref object of Widget
proc newDivider*(): Divider = result = Divider(); result.node = newSvgGroup(); result.addClass("divider")

type ComboBox* = ref object of Widget
proc newComboBox*(items: seq[string]): ComboBox =
  result = ComboBox(); result.node = newSvgGroup(); result.addClass("combobox")
  result.addChild(newButton(if items.len > 0: items[0] else: "Select..."))

type Menu* = ref object of Widget
proc newMenu*(): Menu = result = Menu(); result.node = newSvgGroup(); result.addClass("menu"); result.visible = false

type MenuBar* = ref object of Widget
proc newMenuBar*(): MenuBar = result = MenuBar(); result.node = newSvgGroup(); result.addClass("menubar")

type Navbar* = ref object of Widget
proc newNavbar*(): Navbar = result = Navbar(); result.node = newSvgGroup(); result.addClass("navbar")

type Sidebar* = ref object of Widget
proc newSidebar*(): Sidebar = result = Sidebar(); result.node = newSvgGroup(); result.addClass("sidebar")

type Label* = ref object of Widget
proc newLabel*(text: string): Label =
  result = Label(newWidget(newSvgText()))
  SvgText(result.node).text = text
  result.addClass("label")
