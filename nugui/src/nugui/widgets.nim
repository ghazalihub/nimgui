import core, pixie, vmath, layout

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
      w.node.addClass("pressed")
      return true
    of evMouseUp:
      w.node.removeClass("pressed")
      if b.onClicked != nil: b.onClicked()
      return true
    of evMouseEnter:
      w.node.addClass("hovered")
      return true
    of evMouseLeave:
      w.node.removeClass("hovered")
      w.node.removeClass("pressed")
      return true
    else: discard
    return false

type
  Checkbox* = ref object of Button
    checked*: bool
    onToggled*: proc(checked: bool) {.gcsafe.}

proc newCheckbox*(title: string, checked: bool = false): Checkbox =
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

# --- Additional Widgets (Stubs with types) ---

type
  ProgressBar* = ref object of Widget
    progress*: float32
  Tabs* = ref object of Widget
  ListView* = ref object of Widget
  TreeView* = ref object of Widget
  DataGrid* = ref object of Widget
  Badge* = ref object of Widget
  Accordion* = ref object of Widget
  Card* = ref object of Widget
  Drawer* = ref object of Widget
  Breadcrumbs* = ref object of Widget
  Pagination* = ref object of Widget
  Navbar* = ref object of Widget
  Sidebar* = ref object of Widget
  Modal* = ref object of Widget
  Toast* = ref object of Widget
  Tooltip* = ref object of Widget
  DatePicker* = ref object of Widget
  TimePicker* = ref object of Widget
  ColorPicker* = ref object of Widget
  Rating* = ref object of Widget
  Avatar* = ref object of Widget
  Skeleton* = ref object of Widget
  Steps* = ref object of Widget
  Timeline* = ref object of Widget
  FileUpload* = ref object of Widget
  Grid* = ref object of Widget
  Dropdown* = ref object of Widget
  RadioGroup* = ref object of Widget
  Slider* = ref object of Widget
  ScrollArea* = ref object of Widget

# Factory functions
proc newProgressBar*(): ProgressBar = new(result); result.node = newSvgGroup()
proc newTabs*(): Tabs = new(result); result.node = newSvgGroup()
proc newListView*(): ListView = new(result); result.node = newSvgGroup()
proc newTreeView*(): TreeView = new(result); result.node = newSvgGroup()
proc newDataGrid*(): DataGrid = new(result); result.node = newSvgGroup()
proc newBadge*(): Badge = new(result); result.node = newSvgGroup()
proc newAccordion*(): Accordion = new(result); result.node = newSvgGroup()
proc newCard*(): Card = new(result); result.node = newSvgGroup()
proc newDrawer*(): Drawer = new(result); result.node = newSvgGroup()
proc newBreadcrumbs*(): Breadcrumbs = new(result); result.node = newSvgGroup()
proc newPagination*(): Pagination = new(result); result.node = newSvgGroup()
proc newNavbar*(): Navbar = new(result); result.node = newSvgGroup()
proc newSidebar*(): Sidebar = new(result); result.node = newSvgGroup()
proc newModal*(): Modal = new(result); result.node = newSvgGroup()
proc newToast*(): Toast = new(result); result.node = newSvgGroup()
proc newTooltip*(): Tooltip = new(result); result.node = newSvgGroup()
proc newDatePicker*(): DatePicker = new(result); result.node = newSvgGroup()
proc newTimePicker*(): TimePicker = new(result); result.node = newSvgGroup()
proc newColorPicker*(): ColorPicker = new(result); result.node = newSvgGroup()
proc newRating*(): Rating = new(result); result.node = newSvgGroup()
proc newAvatar*(): Avatar = new(result); result.node = newSvgGroup()
proc newSkeleton*(): Skeleton = new(result); result.node = newSvgGroup()
proc newSteps*(): Steps = new(result); result.node = newSvgGroup()
proc newTimeline*(): Timeline = new(result); result.node = newSvgGroup()
proc newFileUpload*(): FileUpload = new(result); result.node = newSvgGroup()
proc newGrid*(): Grid = new(result); result.node = newSvgGroup()
proc newDropdown*(): Dropdown = new(result); result.node = newSvgGroup()
proc newRadioGroup*(): RadioGroup = new(result); result.node = newSvgGroup()
proc newSlider*(): Slider = new(result); result.node = newSvgGroup()
proc newScrollArea*(content: Widget): ScrollArea = new(result); result.node = newSvgGroup(); result.addChild(content)
