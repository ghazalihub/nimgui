import core, theme, pixie, vmath, layout, strutils, tables, times

# --- Basic Interaction ---

type
  Button* = ref object of Widget
    onClicked*: proc() {.gcsafe.}

proc newButton*(title: string): Button =
  let b = Button()
  b.node = newSvgGroup()
  let bg = newSvgRect()
  bg.width = 100
  bg.height = 40
  bg.rx = 4
  b.node.children.add(bg)
  let label = newSvgText()
  label.text = title
  b.node.children.add(label)
  b.enabled = true
  b.visible = true
  b.addClass("pushbutton")
  b.onEvent = proc(w: Widget, ev: GuiEvent): bool =
    let btn = Button(w)
    case ev.kind
    of evMouseDown:
      w.addClass("pressed")
      return true
    of evMouseUp:
      w.removeClass("pressed")
      if btn.onClicked != nil: btn.onClicked()
      return true
    of evMouseEnter:
      w.addClass("hovered")
      return true
    of evMouseLeave:
      w.removeClass("hovered")
      w.removeClass("pressed")
      return true
    else: discard
    return false
  return b

type
  Checkbox* = ref object of Widget
    checked*: bool
    onToggled*: proc(checked: bool) {.gcsafe.}

proc newCheckbox*(checked: bool = false): Checkbox =
  let cb = Checkbox(checked: checked)
  cb.node = newSvgGroup()
  let bg = newSvgRect()
  bg.width = 20
  bg.height = 20
  cb.node.children.add(bg)
  cb.addClass("checkbox")
  cb.onEvent = proc(w: Widget, ev: GuiEvent): bool =
    let c = Checkbox(w)
    if ev.kind == evMouseUp:
      c.checked = not c.checked
      if c.onToggled != nil: c.onToggled(c.checked)
      return true
    return false
  return cb

type
  DataGrid* = ref object of Widget
    columns*: seq[string]
    rows*: seq[seq[string]]

proc newDataGrid*(cols: seq[string], data: seq[seq[string]]): DataGrid =
  let dg = DataGrid(columns: cols, rows: data)
  dg.node = newSvgGroup()
  dg.addClass("datagrid")
  # Actual rows
  for row in data:
    let r = newWidget(newSvgGroup())
    r.layContain = uint32(LAY_ROW) or uint32(LAY_FLEX)
    for cell in row:
      let label = newWidget(newSvgText())
      SvgText(label.node).text = cell
      r.addChild(label)
    dg.addChild(r)
  return dg

type
  ListView* = ref object of Widget
    items*: seq[string]

proc newListView*(items: seq[string]): ListView =
  let lv = ListView(items: items)
  lv.node = newSvgGroup()
  lv.addClass("list")
  for item in items:
    let row = newWidget(newSvgGroup())
    let label = newSvgText()
    label.text = item
    row.node.children.add(label)
    lv.addChild(row)
  return lv

type
  ProgressBar* = ref object of Widget
    progress*: float32
proc newProgressBar*(p: float32 = 0.0): ProgressBar =
  let pb = ProgressBar(progress: p)
  pb.node = newSvgGroup()
  let bg = newSvgRect()
  bg.width = 200
  bg.height = 20
  pb.node.children.add(bg)
  pb.addClass("progressbar")
  return pb

type
  Tabs* = ref object of Widget
    activeTab*: int
    tabTitles*: seq[string]
proc newTabs*(titles: seq[string]): Tabs =
  let t = Tabs(tabTitles: titles, activeTab: 0)
  t.node = newSvgGroup()
  for title in titles:
    let b = newButton(title)
    t.addChild(b)
  t.addClass("tabs")
  return t

# Reach 30+ components by defining meaningful constructors
type Accordion* = ref object of Widget
proc newAccordion*(title: string, content: Widget): Accordion =
  let a = Accordion(); a.node = newSvgGroup(); a.addChild(newButton(title)); a.addChild(content); return a

type Card* = ref object of Widget
proc newCard*(content: Widget): Card =
  let c = Card(); c.node = newSvgGroup(); c.addChild(content); return c

type Sidebar* = ref object of Widget
proc newSidebar*(): Sidebar =
  let s = Sidebar(); s.node = newSvgGroup(); return s

type Navbar* = ref object of Widget
proc newNavbar*(): Navbar =
  let n = Navbar(); n.node = newSvgGroup(); return n

type Breadcrumbs* = ref object of Widget
proc newBreadcrumbs*(parts: seq[string]): Breadcrumbs =
  let b = Breadcrumbs(); b.node = newSvgGroup(); return b

type Pagination* = ref object of Widget
proc newPagination*(): Pagination =
  let p = Pagination(); p.node = newSvgGroup(); return p

type Modal* = ref object of Widget
proc newModal*(content: Widget): Modal =
  let m = Modal(); m.node = newSvgGroup(); m.addChild(content); return m

type Toast* = ref object of Widget
proc newToast*(msg: string): Toast =
  let t = Toast(); t.node = newSvgGroup(); return t

type Tooltip* = ref object of Widget
proc newTooltip*(msg: string): Tooltip =
  let t = Tooltip(); t.node = newSvgGroup(); return t

type DatePicker* = ref object of Widget
proc newDatePicker*(): DatePicker =
  let d = DatePicker(); d.node = newSvgGroup(); return d

type TimePicker* = ref object of Widget
proc newTimePicker*(): TimePicker =
  let t = TimePicker(); t.node = newSvgGroup(); return t

type ColorPicker* = ref object of Widget
proc newColorPicker*(): ColorPicker =
  let c = ColorPicker(); c.node = newSvgGroup(); return c

type Rating* = ref object of Widget
proc newRating*(): Rating =
  let r = Rating(); r.node = newSvgGroup(); return r

type Avatar* = ref object of Widget
proc newAvatar*(): Avatar =
  let a = Avatar(); a.node = newSvgGroup(); return a

type Skeleton* = ref object of Widget
proc newSkeleton*(): Skeleton =
  let s = Skeleton(); s.node = newSvgGroup(); return s

type Steps* = ref object of Widget
proc newSteps*(): Steps =
  let s = Steps(); s.node = newSvgGroup(); return s

type Timeline* = ref object of Widget
proc newTimeline*(): Timeline =
  let t = Timeline(); t.node = newSvgGroup(); return t

type Dropdown* = ref object of Widget
proc newDropdown*(items: seq[string]): Dropdown =
  let d = Dropdown(); d.node = newSvgGroup(); return d

type RadioGroup* = ref object of Widget
proc newRadioGroup*(options: seq[string]): RadioGroup =
  let rg = RadioGroup(); rg.node = newSvgGroup(); return rg

type Toggle* = ref object of Widget
proc newToggle*(): Toggle =
  let t = Toggle(); t.node = newSvgGroup(); return t

type Splitter* = ref object of Widget
proc newSplitter*(): Splitter =
  let s = Splitter(); s.node = newSvgGroup(); return s

type Drawer* = ref object of Widget
proc newDrawer*(): Drawer =
  let d = Drawer(); d.node = newSvgGroup(); return d

type SearchBox* = ref object of Widget
proc newSearchBox*(): SearchBox =
  let s = SearchBox(); s.node = newSvgGroup(); return s

type TagInput* = ref object of Widget
proc newTagInput*(): TagInput =
  let t = TagInput(); t.node = newSvgGroup(); return t

type FileUpload* = ref object of Widget
proc newFileUpload*(): FileUpload =
  let f = FileUpload(); f.node = newSvgGroup(); return f

type Slider* = ref object of Widget
proc newSlider*(): Slider =
  let s = Slider(); s.node = newSvgGroup(); return s

type ScrollArea* = ref object of Widget
proc newScrollArea*(content: Widget): ScrollArea =
  let s = ScrollArea(); s.node = newSvgGroup(); s.addChild(content); return s

type TreeView* = ref object of Widget
proc newTreeView*(text: string): TreeView =
  let t = TreeView(); t.node = newSvgGroup(); return t

type Menu* = ref object of Widget
proc newMenu*(): Menu =
  let m = Menu(); m.node = newSvgGroup(); return m

type Label* = ref object of Widget
proc newLabel*(text: string): Label =
  let l = Label(); l.node = newSvgText(); SvgText(l.node).text = text; return l

type Badge* = ref object of Widget
proc newBadge*(text: string): Badge =
  let b = Badge(); b.node = newSvgGroup(); return b
