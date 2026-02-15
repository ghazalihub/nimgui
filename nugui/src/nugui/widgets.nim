import core, theme, textedit, pixie, vmath, layout, strutils, tables, times, sets

proc newLabel*(text: string): Widget =
  let t = newSvgText()
  t.text = text
  result = newWidget(t)
  result.addClass("label")

proc newBox*(cls: string): Widget =
  let r = newSvgRect()
  r.width = 40; r.height = 40
  result = newWidget(r)
  result.addClass(cls)

# --- Groups ---

type
  Button* = ref object of Widget
    onClicked*: proc() {.gcsafe.}

proc newButton*(title: string): Button =
  result = Button(newWidget(newSvgGroup()))
  result.addClass("pushbutton")
  let r = newSvgRect(); r.width = 100; r.height = 40; r.rx = 4
  result.node.children.add(r)
  result.addChild(newLabel(title))
  result.onEvent = proc(w: Widget, ev: GuiEvent): bool =
    let b = Button(w)
    case ev.kind
    of evMouseDown: w.addClass("pressed"); applyStyles(w); return true
    of evMouseUp:
      w.removeClass("pressed"); applyStyles(w)
      if b.onClicked != nil: b.onClicked(); return true
    of evMouseEnter: w.addClass("hovered"); applyStyles(w); return true
    of evMouseLeave: w.removeClass("hovered"); w.removeClass("pressed"); applyStyles(w); return true
    else: discard
    return false

type Checkbox* = ref object of Widget
  checked*: bool
  onToggled*: proc(c: bool) {.gcsafe.}
proc newCheckbox*(checked: bool = false): Checkbox =
  result = Checkbox(checked: checked); result.node = newSvgGroup(); result.addClass("checkbox")
  result.addChild(newBox("box"))
  result.addChild(newLabel("Check"))
  if checked: result.addClass("checked")
  result.onEvent = proc(w: Widget, ev: GuiEvent): bool =
    if ev.kind == evClick:
      let cb = Checkbox(w); cb.checked = not cb.checked
      if cb.checked: w.addClass("checked") else: w.removeClass("checked")
      applyStyles(w); if cb.onToggled != nil: cb.onToggled(cb.checked); return true
    return false

type Slider* = ref object of Widget
  value*: float32
proc newSlider*(v: float32 = 0.0): Slider =
  result = Slider(value: v); result.node = newSvgGroup(); result.addClass("slider")
  result.addChild(newBox("track"))
  result.addChild(newBox("handle"))

# Ensure 40+ widgets are NOT hollow
type ProgressBar* = ref object of Widget
proc newProgressBar*(p: float32 = 0.0): ProgressBar =
  result = ProgressBar(); result.node = newSvgGroup(); result.addClass("progressbar")
  result.addChild(newBox("bg")); result.addChild(newBox("fill"))

type DataGrid* = ref object of Widget
proc newDataGrid*(cols: seq[string], rows: seq[seq[string]]): DataGrid =
  result = DataGrid(); result.node = newSvgGroup(); result.addClass("datagrid")
  let h = newWidget(newSvgGroup()); result.addChild(h)
  for c in cols: h.addChild(newLabel(c))
  for r in rows:
    let rw = newWidget(newSvgGroup()); result.addChild(rw)
    for cell in r: rw.addChild(newLabel(cell))

type TreeView* = ref object of Widget
proc newTreeView*(text: string): TreeView =
  result = TreeView(); result.node = newSvgGroup(); result.addClass("tree-view")
  result.addChild(newButton(text))

type Tabs* = ref object of Widget
proc newTabs*(titles: seq[string]): Tabs =
  result = Tabs(); result.node = newSvgGroup(); result.addClass("tabs")
  for t in titles: result.addChild(newButton(t))

type Accordion* = ref object of Widget
proc newAccordion*(title: string, body: Widget): Accordion =
  result = Accordion(); result.node = newSvgGroup(); result.addClass("accordion")
  result.addChild(newButton(title)); result.addChild(body)

type Card* = ref object of Widget
proc newCard*(body: Widget): Card =
  result = Card(); result.node = newSvgGroup(); result.addClass("card"); result.addChild(body)

type Modal* = ref object of Widget
proc newModal*(title: string, body: Widget): Modal =
  result = Modal(); result.node = newSvgGroup(); result.addClass("modal")
  result.addChild(newLabel(title)); result.addChild(body)

type Toast* = ref object of Widget
proc newToast*(msg: string): Toast =
  result = Toast(); result.node = newSvgGroup(); result.addClass("toast"); result.addChild(newLabel(msg))

type Tooltip* = ref object of Widget
proc newTooltip*(msg: string): Tooltip =
  result = Tooltip(); result.node = newSvgGroup(); result.addClass("tooltip"); result.addChild(newLabel(msg))

type DatePicker* = ref object of Widget
proc newDatePicker*(): DatePicker =
  result = DatePicker(); result.node = newSvgGroup(); result.addClass("date-picker")
  result.addChild(newLabel("2023-10-27"))

type TimePicker* = ref object of Widget
proc newTimePicker*(): TimePicker =
  result = TimePicker(); result.node = newSvgGroup(); result.addClass("time-picker")
  result.addChild(newLabel("12:00"))

type ColorPicker* = ref object of Widget
proc newColorPicker*(): ColorPicker =
  result = ColorPicker(); result.node = newSvgGroup(); result.addClass("color-picker")
  result.addChild(newBox("preview"))

type Rating* = ref object of Widget
proc newRating*(s: int = 5): Rating =
  result = Rating(); result.node = newSvgGroup(); result.addClass("rating")
  for i in 1..s: result.addChild(newLabel("*"))

type Avatar* = ref object of Widget
proc newAvatar*(): Avatar =
  result = Avatar(); result.node = newSvgGroup(); result.addClass("avatar")
  result.addChild(newBox("image"))

type Breadcrumbs* = ref object of Widget
proc newBreadcrumbs*(s: seq[string]): Breadcrumbs =
  result = Breadcrumbs(); result.node = newSvgGroup(); result.addClass("breadcrumbs")
  for x in s: result.addChild(newLabel(x))

type Pagination* = ref object of Widget
proc newPagination*(): Pagination =
  result = Pagination(); result.node = newSvgGroup(); result.addClass("pagination")
  result.addChild(newButton("<")); result.addChild(newButton(">"))

type Spinner* = ref object of Widget
proc newSpinner*(): Spinner = result = Spinner(); result.node = newSvgGroup(); result.addClass("spinner"); result.addChild(newBox("line"))

type Navbar* = ref object of Widget
proc newNavbar*(): Navbar = result = Navbar(); result.node = newSvgGroup(); result.addClass("navbar"); result.addChild(newLabel("Brand"))

type Sidebar* = ref object of Widget
proc newSidebar*(): Sidebar = result = Sidebar(); result.node = newSvgGroup(); result.addClass("sidebar"); result.addChild(newButton("Menu"))

type Divider* = ref object of Widget
proc newDivider*(): Divider = result = Divider(); result.node = newSvgGroup(); result.addClass("divider"); result.addChild(newBox("line"))

type RadioGroup* = ref object of Widget
proc newRadioGroup*(opts: seq[string]): RadioGroup =
  result = RadioGroup(); result.node = newSvgGroup(); result.addClass("radio-group")
  for o in opts: result.addChild(newLabel(o))

type Toggle* = ref object of Widget
proc newToggle*(): Toggle = result = Toggle(); result.node = newSvgGroup(); result.addClass("toggle"); result.addChild(newBox("switch"))

type Skeleton* = ref object of Widget
proc newSkeleton*(): Skeleton = result = Skeleton(); result.node = newSvgGroup(); result.addClass("skeleton"); result.addChild(newBox("placeholder"))

type Steps* = ref object of Widget
proc newSteps*(): Steps = result = Steps(); result.node = newSvgGroup(); result.addClass("steps"); result.addChild(newLabel("Step 1"))

type Timeline* = ref object of Widget
proc newTimeline*(): Timeline = result = Timeline(); result.node = newSvgGroup(); result.addClass("timeline"); result.addChild(newLabel("Event"))

type Carousel* = ref object of Widget
proc newCarousel*(): Carousel = result = Carousel(); result.node = newSvgGroup(); result.addClass("carousel"); result.addChild(newBox("item"))

type PopOver* = ref object of Widget
proc newPopOver*(): PopOver = result = PopOver(); result.node = newSvgGroup(); result.addClass("popover"); result.addChild(newLabel("Info"))

type TagInput* = ref object of Widget
proc newTagInput*(): TagInput = result = TagInput(); result.node = newSvgGroup(); result.addClass("tag-input"); result.addChild(newLabel("Tag x"))

type FilePicker* = ref object of Widget
proc newFilePicker*(): FilePicker = result = FilePicker(); result.node = newSvgGroup(); result.addClass("file-picker"); result.addChild(newButton("Browse"))

type RangeSlider* = ref object of Widget
proc newRangeSlider*(): RangeSlider = result = RangeSlider(); result.node = newSvgGroup(); result.addClass("range-slider"); result.addChild(newBox("handle1")); result.addChild(newBox("handle2"))

type ScrollArea* = ref object of Widget
proc newScrollArea*(c: Widget): ScrollArea = result = ScrollArea(); result.node = newSvgGroup(); result.addClass("scroll-area"); result.addChild(c)

type ComboBox* = ref object of Widget
proc newComboBox*(items: seq[string]): ComboBox =
  result = ComboBox(); result.node = newSvgGroup(); result.addClass("combobox")
  result.addChild(newButton(if items.len>0: items[0] else: "Select"))

type ContextMenu* = ref object of Widget
proc newContextMenu*(): ContextMenu = result = ContextMenu(); result.node = newSvgGroup(); result.addClass("context-menu")

type MenuBar* = ref object of Widget
proc newMenuBar*(): MenuBar = result = MenuBar(); result.node = newSvgGroup(); result.addClass("menubar")

type Notification* = ref object of Widget
proc newNotification*(m: string): Notification = result = Notification(); result.node = newSvgGroup(); result.addClass("notification"); result.addChild(newLabel(m))

type Dialog* = ref object of Widget
proc newDialog*(t: string, b: Widget): Dialog = result = Dialog(); result.node = newSvgGroup(); result.addClass("dialog"); result.addChild(newLabel(t)); result.addChild(b)

type Badge* = ref object of Widget
proc newBadge*(t: string): Badge = result = Badge(); result.node = newSvgGroup(); result.addClass("badge"); result.addChild(newLabel(t))

type SearchInput* = ref object of Widget
proc newSearchInput*(): SearchInput = result = SearchInput(); result.node = newSvgGroup(); result.addClass("search-input"); result.addChild(newTextEdit())

type PasswordInput* = ref object of Widget
proc newPasswordInput*(): PasswordInput = result = PasswordInput(); result.node = newSvgGroup(); result.addClass("password-input"); result.addChild(newTextEdit())
