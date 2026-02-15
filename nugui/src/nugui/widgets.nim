import core, theme, textedit, pixie, vmath, layout, strutils, tables, times, sets

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

proc newLabel*(text: string): Widget =
  let t = newSvgText(); t.text = text; result = newWidget(t); result.addClass("label")

type Button* = ref object of Widget
  onClicked*: proc() {.gcsafe.}
proc newButton*(title: string): Button =
  result = Button(createWidgetFromTemplate("pushbutton"))
  let n = result.findNodeByClass("title"); if n != nil and n of SvgText: SvgText(n).text = title
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
  cb.checked = checked; let n = cb.findNodeByClass("label"); if n != nil and n of SvgText: SvgText(n).text = label
  if checked: cb.addClass("checked")
  cb.onEvent = proc(w: Widget, ev: GuiEvent): bool =
    let c = Checkbox(w)
    if ev.kind == evClick: (c.checked = not c.checked; if c.checked: w.addClass("checked") else: w.removeClass("checked"); applyStyles(w); if c.onToggled != nil: c.onToggled(c.checked); return true)
    return false
proc newCheckbox*(label: string, checked: bool = false): Checkbox = (result = Checkbox(createWidgetFromTemplate("checkbox")); initCheckbox(result, label, checked))

type DataGrid* = ref object of Widget
proc newDataGrid*(headers: seq[string], data: seq[seq[string]]): DataGrid =
  result = DataGrid(createWidgetFromTemplate("datagrid"))
  let hr = result.findWidgetByClass("header-row"); let rows = result.findWidgetByClass("rows")
  if hr != nil: (for h in headers: hr.addChild(newLabel(h)))
  if rows != nil:
    for row in data:
      let rw = newWidget(); rw.addClass("row"); rw.attributes["layout"] = "flex"; rw.attributes["flex-direction"] = "row"
      for cell in row: rw.addChild(newLabel(cell))
      rows.addChild(rw)

type ComboBox* = ref object of Widget
  options*: seq[string]; index*: int
proc newComboBox*(options: seq[string]): ComboBox =
  result = ComboBox(createWidgetFromTemplate("combobox")); result.options = options
  let n = result.findNodeByClass("current-text"); if n != nil and n of SvgText and options.len > 0: SvgText(n).text = options[0]
  result.onEvent = proc(w: Widget, ev: GuiEvent): bool =
    if ev.kind == evClick: (echo "Dropdown menu would open here"); return true
    return false

type TextBox* = ref object of Widget
  editor*: TextEditor
proc newTextBox*(text: string = ""): TextBox =
  result = TextBox(createWidgetFromTemplate("textbox")); result.editor = newTextEditor(); result.editor.setText(text)
  result.onEvent = proc(w: Widget, ev: GuiEvent): bool =
    let tb = TextBox(w)
    case ev.kind
    of evClick: w.window.focusWidget(w); return true
    of evKeyDown: (if w.window != nil and w.window.focusedWidget == w: (tb.editor.handleKey(ev.key, ev.mods); let n = tb.findNodeByClass("content"); if n != nil and n of SvgText: SvgText(n).text = tb.editor.text; return true))
    of evTextInput: (if w.window != nil and w.window.focusedWidget == w: (tb.editor.insert(ev.text); let n = tb.findNodeByClass("content"); if n != nil and n of SvgText: SvgText(n).text = tb.editor.text; return true))
    else: discard
    return false

type Slider* = ref object of Widget
  value*: float32
proc newSlider*(value: float32 = 0.5): Slider =
  result = Slider(createWidgetFromTemplate("slider")); result.value = value
  result.onEvent = proc(w: Widget, ev: GuiEvent): bool =
    let s = Slider(w)
    if ev.kind == evMouseDown or (ev.kind == evMouseMove and "pressed" in w.classes):
      s.value = clamp((ev.pos.x - w.computedRect.x) / w.computedRect.w, 0.0, 1.0)
      let h = s.findNodeByClass("handle-container"); if h != nil: h.metadata["transform"] = "translate(" & $(s.value * w.computedRect.w) & " 0)"
      if ev.kind == evMouseDown: w.addClass("pressed")
      return true
    elif ev.kind == evMouseUp: w.removeClass("pressed"); return true
    return false

type Switch* = ref object of Checkbox
proc newSwitch*(label: string, checked: bool = false): Switch = (result = Switch(createWidgetFromTemplate("checkbox")); initCheckbox(result, label, checked); result.addClass("switch"))

type ProgressBar* = ref object of Widget
proc newProgressBar*(p: float32 = 0.0): ProgressBar =
  result = ProgressBar(createWidgetFromTemplate("progressbar"))
  let f = result.findNodeByClass("fill"); if f != nil and f of SvgRect: SvgRect(f).width = p * 200 # Fixed width base

type Carousel* = ref object of Widget
  index*: int
proc newCarousel*(): Carousel =
  result = Carousel(createWidgetFromTemplate("carousel"))
  result.onEvent = proc(w: Widget, ev: GuiEvent): bool =
    if ev.kind == evClick: (let c = Carousel(w); c.index = (c.index + 1) mod 3; return true)
    return false

type PopOver* = ref object of Widget
proc newPopOver*(): PopOver = result = PopOver(createWidgetFromTemplate("popover"))
type Radio* = ref object of Widget
proc newRadio*(label: string, checked: bool = false): Radio =
  result = Radio(createWidgetFromTemplate("radio"))
  let n = result.findNodeByClass("label"); if n != nil and n of SvgText: SvgText(n).text = label
  if checked: result.addClass("checked")
type DatePicker* = ref object of Widget
proc newDatePicker*(): DatePicker = result = DatePicker(createWidgetFromTemplate("datepicker"))
type TreeItem* = ref object of Widget
proc newTreeItem*(label: string): TreeItem =
  result = TreeItem(createWidgetFromTemplate("tree-item"))
  let n = result.findNodeByClass("label"); if n != nil and n of SvgText: SvgText(n).text = label
type ColorPicker* = ref object of Widget
proc newColorPicker*(): ColorPicker = result = ColorPicker(createWidgetFromTemplate("color-picker"))
type Badge* = ref object of Widget
proc newBadge*(v: string): Badge =
  result = Badge(createWidgetFromTemplate("badge"))
  let n = result.findNodeByClass("label"); if n != nil and n of SvgText: SvgText(n).text = v
type Avatar* = ref object of Widget
proc newAvatar*(i: string): Avatar =
  result = Avatar(createWidgetFromTemplate("avatar"))
  let n = result.findNodeByClass("initials"); if n != nil and n of SvgText: SvgText(n).text = i
type Rating* = ref object of Widget
proc newRating*(r: int): Rating = result = Rating(createWidgetFromTemplate("rating"))
type Tooltip* = ref object of Widget
proc newTooltip*(t: string): Tooltip = result = Tooltip(createWidgetFromTemplate("tooltip"))
type Skeleton* = ref object of Widget
proc newSkeleton*(): Skeleton = result = Skeleton(createWidgetFromTemplate("skeleton"))
type Breadcrumbs* = ref object of Widget
proc newBreadcrumbs*(it: seq[string]): Breadcrumbs = result = Breadcrumbs(createWidgetFromTemplate("breadcrumbs"))
type Pagination* = ref object of Widget
proc newPagination*(c: int): Pagination = result = Pagination(createWidgetFromTemplate("pagination"))
type Steps* = ref object of Widget
proc newSteps*(it: seq[string]): Steps = result = Steps(createWidgetFromTemplate("steps"))
type Tabs* = ref object of Widget
proc newTabs*(it: seq[string]): Tabs = result = Tabs(createWidgetFromTemplate("tabs"))
type Accordion* = ref object of Widget
proc newAccordion*(t: string): Accordion =
  result = Accordion(createWidgetFromTemplate("accordion"))
  let n = result.findNodeByClass("title"); if n != nil and n of SvgText: SvgText(n).text = t
type Card* = ref object of Widget
proc newCard*(t: string): Card =
  result = Card(createWidgetFromTemplate("card"))
  let h = result.findWidgetByClass("header"); if h != nil: h.addChild(newLabel(t))
type ScrollArea* = ref object of Widget
proc newScrollArea*(c: Widget): ScrollArea = result = ScrollArea(createWidgetFromTemplate("scrollarea"))
type Navbar* = ref object of Widget
proc newNavbar*(l: string): Navbar =
  result = Navbar(createWidgetFromTemplate("navbar"))
  let n = result.findNodeByClass("logo"); if n != nil and n of SvgText: SvgText(n).text = l
type Sidebar* = ref object of Widget
proc newSidebar*(): Sidebar = result = Sidebar(createWidgetFromTemplate("sidebar"))
type Divider* = ref object of Widget
proc newDivider*(): Divider = result = Divider(createWidgetFromTemplate("divider"))
type Splitter* = ref object of Widget
proc newSplitter*(): Splitter = result = Splitter(createWidgetFromTemplate("splitter"))
type Modal* = ref object of Widget
proc newModal*(t: string): Modal = result = Modal(createWidgetFromTemplate("modal"))
type Toast* = ref object of Widget
proc newToast*(m: string): Toast = result = Toast(createWidgetFromTemplate("toast"))
type Drawer* = ref object of Widget
proc newDrawer*(): Drawer = result = Drawer(createWidgetFromTemplate("drawer"))
type Timeline* = ref object of Widget
proc newTimeline*(): Timeline = result = Timeline(createWidgetFromTemplate("timeline"))
type Tag* = ref object of Widget
proc newTag*(l: string): Tag = result = Tag(createWidgetFromTemplate("tag"))
type RangeSlider* = ref object of Widget
proc newRangeSlider*(): RangeSlider = result = RangeSlider(createWidgetFromTemplate("range-slider"))
type SearchInput* = ref object of Widget
proc newSearchInput*(): SearchInput = (result = SearchInput(newTextBox()); result.addClass("search-input"))
type PasswordInput* = ref object of Widget
proc newPasswordInput*(): PasswordInput = (result = PasswordInput(newTextBox()); result.addClass("password-input"))
type FilePicker* = ref object of Widget
proc newFilePicker*(): FilePicker = (result = FilePicker(newWidget()); result.addChild(newButton("Browse...")))
type TagInput* = ref object of Widget
proc newTagInput*(): TagInput = (result = TagInput(newWidget()); result.addChild(newTextBox()))
type TimePicker* = ref object of Widget
proc newTimePicker*(): TimePicker = (result = TimePicker(newWidget()); result.addChild(newLabel("12:00")))
type ListView* = ref object of Widget
proc newListView*(): ListView = (result = ListView(newWidget()); result.addClass("list-view"))
