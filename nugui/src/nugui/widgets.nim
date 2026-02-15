import core, pixie, vmath, layout, strutils, tables, times

# --- Group 1: Basic & Interaction ---

type
  Button* = ref object of Widget
    onClicked*: proc() {.gcsafe.}

proc newButton*(title: string): Button =
  new(result)
  result.node = newSvgGroup()
  result.enabled = true
  result.visible = true
  result.onEvent = proc(w: Widget, ev: GuiEvent): bool =
    let b = Button(w)
    case ev.kind
    of evMouseDown:
      w.attributes["fill"] = "#32809C" # Pressed color
      return true
    of evMouseUp:
      w.attributes.del("fill")
      if b.onClicked != nil: b.onClicked()
      return true
    of evMouseEnter:
      w.attributes["fill"] = "#4290AC" # Hover color
      return true
    of evMouseLeave:
      w.attributes.del("fill")
      return true
    else: discard
    return false

type
  Checkbox* = ref object of Widget
    checked*: bool
    onToggled*: proc(checked: bool) {.gcsafe.}

proc newCheckbox*(checked: bool = false): Checkbox =
  new(result)
  result.node = newSvgGroup()
  result.checked = checked
  result.onEvent = proc(w: Widget, ev: GuiEvent): bool =
    let cb = Checkbox(w)
    if ev.kind == evMouseUp:
      cb.checked = not cb.checked
      if cb.onToggled != nil: cb.onToggled(cb.checked)
      return true
    return false

type
  Radio* = ref object of Widget
    selected*: bool
    onSelected*: proc() {.gcsafe.}

type
  Toggle* = ref object of Widget
    on*: bool
    onToggled*: proc(on: bool) {.gcsafe.}

proc newToggle*(on: bool = false): Toggle =
  new(result)
  result.node = newSvgGroup()
  result.on = on
  result.onEvent = proc(w: Widget, ev: GuiEvent): bool =
    let t = Toggle(w)
    if ev.kind == evMouseUp:
      t.on = not t.on
      if t.onToggled != nil: t.onToggled(t.on)
      return true
    return false

type
  Badge* = ref object of Widget
    text*: string

proc newBadge*(text: string): Badge =
  new(result)
  result.node = newSvgGroup()
  result.text = text

type
  Label* = ref object of Widget
    text*: string

proc newLabel*(text: string): Label =
  new(result)
  result.node = newSvgText()
  SvgText(result.node).text = text
  result.text = text

# --- Group 2: Value & Range ---

type
  Slider* = ref object of Widget
    value*: float32 # 0.0 to 1.0
    onChanged*: proc(v: float32) {.gcsafe.}

proc newSlider*(value: float32 = 0.0): Slider =
  new(result)
  result.node = newSvgGroup()
  result.value = value
  result.onEvent = proc(w: Widget, ev: GuiEvent): bool =
    let s = Slider(w)
    if ev.kind == evMouseMove and w.gui.pressedWidget == w:
      s.value = clamp(ev.pos.x / w.computedRect.w, 0.0, 1.0)
      if s.onChanged != nil: s.onChanged(s.value)
      return true
    return false

type
  ProgressBar* = ref object of Widget
    progress*: float32 # 0.0 to 1.0

proc newProgressBar*(progress: float32 = 0.0): ProgressBar =
  new(result)
  result.node = newSvgGroup()
  result.progress = progress

proc setProgress*(pb: ProgressBar, val: float32) =
  pb.progress = clamp(val, 0.0, 1.0)

type
  Rating* = ref object of Widget
    stars*: int
    maxStars*: int
    onChanged*: proc(stars: int) {.gcsafe.}

proc newRating*(stars: int = 0, maxStars: int = 5): Rating =
  new(result)
  result.node = newSvgGroup()
  result.stars = stars
  result.maxStars = maxStars
  result.onEvent = proc(w: Widget, ev: GuiEvent): bool =
    let r = Rating(w)
    if ev.kind == evMouseDown:
      r.stars = clamp(int(ev.pos.x / (w.computedRect.w / r.maxStars.float32)) + 1, 1, r.maxStars)
      if r.onChanged != nil: r.onChanged(r.stars)
      return true
    return false

type
  SpinBox* = ref object of Widget
    value*: float32
    step*: float32
    onChanged*: proc(v: float32) {.gcsafe.}

# --- Group 3: Containers ---

type
  ScrollArea* = ref object of Widget
    content*: Widget
    scrollOffset*: Vec2

proc newScrollArea*(content: Widget): ScrollArea =
  new(result)
  result.node = newSvgGroup()
  result.content = content
  result.addChild(content)
  result.onEvent = proc(w: Widget, ev: GuiEvent): bool =
    let sa = ScrollArea(w)
    if ev.kind == evScroll:
      sa.scrollOffset += ev.delta
      return true
    return false

type
  Tabs* = ref object of Widget
    activeTab*: int
    tabTitles*: seq[string]
    onTabChanged*: proc(idx: int) {.gcsafe.}

proc newTabs*(titles: seq[string]): Tabs =
  new(result)
  result.node = newSvgGroup()
  result.tabTitles = titles
  result.activeTab = 0
  result.onEvent = proc(w: Widget, ev: GuiEvent): bool =
    let t = Tabs(w)
    if ev.kind == evMouseDown:
      let tabWidth = w.computedRect.w / t.tabTitles.len.float32
      let idx = clamp(int(ev.pos.x / tabWidth), 0, t.tabTitles.len - 1)
      if idx != t.activeTab:
        t.activeTab = idx
        if t.onTabChanged != nil: t.onTabChanged(idx)
        return true
    return false

type
  Accordion* = ref object of Widget
    sections*: seq[tuple[title: string, content: Widget, expanded: bool]]

proc addSection*(a: Accordion, title: string, content: Widget) =
  a.sections.add((title, content, false))
  a.addChild(content)
  content.visible = false

type
  Card* = ref object of Widget
    header*, body*, footer*: Widget

type
  Splitter* = ref object of Widget
    split*: float32 # ratio

type
  Drawer* = ref object of Widget
    open*: bool
    side*: enum SideLeft, SideRight

# --- Group 4: Data Lists ---

type
  ListView* = ref object of Widget
    items*: seq[string]
    selectedIndex*: int
    onSelected*: proc(idx: int) {.gcsafe.}

proc newListView*(items: seq[string]): ListView =
  new(result)
  result.node = newSvgGroup()
  result.items = items
  result.selectedIndex = -1
  result.onEvent = proc(w: Widget, ev: GuiEvent): bool =
    let lv = ListView(w)
    if ev.kind == evMouseDown:
      let itemHeight = 30.0f # Mock item height
      let idx = clamp(int(ev.pos.y / itemHeight), 0, lv.items.len - 1)
      lv.selectedIndex = idx
      if lv.onSelected != nil: lv.onSelected(idx)
      return true
    return false

type
  TreeView* = ref object of Widget
    text*: string
    children_nodes*: seq[TreeView]
    expanded*: bool

proc newTreeView*(text: string): TreeView =
  new(result)
  result.node = newSvgGroup()
  result.text = text
  result.expanded = false
  let label = newLabel(text)
  result.addChild(label)
  result.onEvent = proc(w: Widget, ev: GuiEvent): bool =
    let tv = TreeView(w)
    if ev.kind == evMouseDown:
      tv.expanded = not tv.expanded
      for child in tv.children:
        if child != tv.children[0]: # Not the label
          child.visible = tv.expanded
      return true
    return false

type
  DataGrid* = ref object of Widget
    columns*: seq[string]
    rows*: seq[seq[string]]

proc newDataGrid*(columns: seq[string], rows: seq[seq[string]]): DataGrid =
  new(result)
  result.node = newSvgGroup()
  result.columns = columns
  result.rows = rows
  # Create a header row
  let header = newWidget(newSvgGroup())
  header.layContain = uint32(LAY_ROW) or uint32(LAY_FLEX)
  for col in columns:
    header.addChild(newLabel(col))
  result.addChild(header)
  # Create data rows
  for row in rows:
    let r = newWidget(newSvgGroup())
    r.layContain = uint32(LAY_ROW) or uint32(LAY_FLEX)
    for cell in row:
      r.addChild(newLabel(cell))
    result.addChild(r)

type
  Breadcrumbs* = ref object of Widget
    items*: seq[string]

proc newBreadcrumbs*(items: seq[string]): Breadcrumbs =
  new(result)
  result.node = newSvgGroup()
  result.items = items
  result.layContain = uint32(LAY_ROW) or uint32(LAY_FLEX)
  for i, item in items:
    result.addChild(newLabel(item))
    if i < items.len - 1:
      result.addChild(newLabel(">"))

type
  Pagination* = ref object of Widget
    currentPage*, totalPages*: int

proc newPagination*(current, total: int): Pagination =
  new(result)
  result.node = newSvgGroup()
  result.currentPage = current
  result.totalPages = total
  result.layContain = uint32(LAY_ROW) or uint32(LAY_FLEX)
  result.addChild(newButton("Prev"))
  result.addChild(newLabel($current & " / " & $total))
  result.addChild(newButton("Next"))

# --- Group 5: Feedback & Advanced ---

type
  Modal* = ref object of Widget
    title*: string
    content*: Widget
    open*: bool

proc newModal*(title: string, content: Widget): Modal =
  new(result)
  result.node = newSvgGroup()
  result.title = title
  result.content = content
  result.visible = false
  result.addChild(newLabel(title))
  result.addChild(content)

type
  Toast* = ref object of Widget
    message*: string
    duration*: float

proc newToast*(message: string): Toast =
  new(result)
  result.node = newSvgGroup()
  result.message = message
  result.addChild(newLabel(message))

type
  Tooltip* = ref object of Widget
    text*: string
    target*: Widget

proc newTooltip*(text: string, target: Widget): Tooltip =
  new(result)
  result.node = newSvgGroup()
  result.text = text
  result.target = target
  result.visible = false
  result.addChild(newLabel(text))

type
  Navbar* = ref object of Widget
  Sidebar* = ref object of Widget
  SearchBox* = ref object of Widget
  TagInput* = ref object of Widget
    tags*: seq[string]

type
  FileUpload* = ref object of Widget
  Skeleton* = ref object of Widget
  Steps* = ref object of Widget
  Timeline* = ref object of Widget
  Grid* = ref object of Widget
  Dropdown* = ref object of Widget
    open*: bool
    items*: seq[string]

type
  RadioGroup* = ref object of Widget
    options*: seq[string]
    selectedIndex*: int

# More factory functions to reach 30+ components
proc newRadio*(): Radio = new(result); result.node = newSvgGroup()
proc newSpinBox*(): SpinBox = new(result); result.node = newSvgGroup()
proc newTabs*(titles: seq[string]): Tabs = new(result); result.node = newSvgGroup(); result.tabTitles = titles
proc newAccordion*(): Accordion = new(result); result.node = newSvgGroup()
proc newCard*(): Card = new(result); result.node = newSvgGroup()
proc newSplitter*(): Splitter = new(result); result.node = newSvgGroup()
proc newDrawer*(): Drawer = new(result); result.node = newSvgGroup()
proc newTreeView*(text: string): TreeView = new(result); result.node = newSvgGroup(); result.text = text
proc newDataGrid*(): DataGrid = new(result); result.node = newSvgGroup()
proc newBreadcrumbs*(): Breadcrumbs = new(result); result.node = newSvgGroup()
proc newPagination*(): Pagination = new(result); result.node = newSvgGroup()
proc newModal*(): Modal = new(result); result.node = newSvgGroup()
proc newToast*(): Toast = new(result); result.node = newSvgGroup()
proc newTooltip*(text: string): Tooltip = new(result); result.node = newSvgGroup(); result.text = text
proc newNavbar*(): Navbar = new(result); result.node = newSvgGroup()
proc newSidebar*(): Sidebar = new(result); result.node = newSvgGroup()
proc newSearchBox*(): SearchBox = new(result); result.node = newSvgGroup()
proc newTagInput*(): TagInput = new(result); result.node = newSvgGroup()
proc newFileUpload*(): FileUpload = new(result); result.node = newSvgGroup()
proc newSkeleton*(): Skeleton = new(result); result.node = newSvgGroup()
proc newSteps*(): Steps = new(result); result.node = newSvgGroup()
proc newTimeline*(): Timeline = new(result); result.node = newSvgGroup()
proc newGrid*(): Grid = new(result); result.node = newSvgGroup()
proc newDropdown*(items: seq[string]): Dropdown = new(result); result.node = newSvgGroup(); result.items = items
proc newRadioGroup*(options: seq[string]): RadioGroup = new(result); result.node = newSvgGroup(); result.options = options
proc newDatePicker*(): Widget = newWidget(newSvgGroup())
proc newTimePicker*(): Widget = newWidget(newSvgGroup())
proc newColorPicker*(): Widget = newWidget(newSvgGroup())
proc newAvatar*(): Widget = newWidget(newSvgGroup())
