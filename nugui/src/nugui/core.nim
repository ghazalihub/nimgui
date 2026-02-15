import pixie, windy, vmath, vmath/rects, tables, sets, layout, times, os, strutils

type
  FocusReason* = enum
    ReasonNone, ReasonPressed, ReasonTab, ReasonWindow, ReasonMenu, ReasonHidden

  EventKind* = enum
    evClick, evMouseDown, evMouseUp, evMouseMove, evKeyDown, evKeyUp, evScroll,
    evMouseEnter, evMouseLeave, evFocusGained, evFocusLost, evTimer,
    evLongPress, evMultiTouch, evOutsideModal, evOutsidePressed,
    evEnabled, evDisabled, evVisible, evInvisible, evScreenResized

  GuiEvent* = object
    kind*: EventKind
    pos*: Vec2
    button*: MouseButton
    keyCode*: KeyCode
    delta*: Vec2
    timestamp*: float
    touchId*: int
    fingerId*: int
    pressure*: float32
    clicks*: int
    data*: pointer # For custom event data

  TimerCallback* = proc(): int {.gcsafe.}

  Timer* = object
    nextTick*: float
    period*: int
    widget*: Widget
    callback*: TimerCallback

  Widget* = ref object of RootObj
    node*: SvgNode
    parent*: Widget
    children*: seq[Widget]
    enabled*: bool
    visible*: bool

    # Layout state (mirrors C++ layout vars)
    layoutId*: LayId
    margins*: LayVec4
    layContain*: uint32
    layBehave*: uint32
    layoutIsolate*: bool
    layoutVarsValid*: bool
    layoutTransform*: Mat3
    computedRect*: Rect # Final result of layout

    # Appearance and state
    xmlClass*: string
    classes*: HashSet[string]
    attributes*: Table[string, string] # Stores raw SVG attributes

    # Event handling
    onEvent*: proc(w: Widget, event: GuiEvent): bool {.gcsafe.}
    eventFilter*: proc(gui: SvgGui, w: Widget, event: var GuiEvent): bool {.gcsafe.}

    # Hooks
    onPrepareLayout*: proc(w: Widget): Rect {.gcsafe.}
    onApplyLayout*: proc(w: Widget, src, dest: Rect): bool {.gcsafe.}

    # Logic flags
    isFocusable*: bool
    isPressedGroupContainer*: bool

  Window* = ref object of Widget
    windyWindow*: windy.Window
    gui*: SvgGui
    focusedWidget*: Widget
    absPosNodes*: seq[Widget]
    winBounds*: Rect
    title*: string

  SvgGui* = ref object
    windows*: seq[Window]
    layoutCtx*: LayContext
    pressedWidget*: Widget
    hoveredWidget*: Widget
    focusedWidget*: Widget
    menuStack*: seq[Widget]
    lastClosedMenu*: Widget

    # Gesture state
    prevFingerPos*: Vec2
    totalFingerDist*: float32
    fingerUpDnTime*: float
    fingerClicks*: int
    flingV*: Vec2

    timers*: seq[Timer]
    inputScale*: float32
    paintScale*: float32

    # Global state
    globalStylesheet*: string # Could be parsed into rules

# Forward declarations
proc dispatchEvent*(gui: SvgGui, w: Widget, event: var GuiEvent): bool
proc setFocused*(gui: SvgGui, widget: Widget, reason: FocusReason = ReasonNone)
proc setPressed*(gui: SvgGui, widget: Widget)
proc onHideWidget*(gui: SvgGui, widget: Widget)

# --- Class/Style management ---

proc hasClass*(w: Widget, cls: string): bool =
  cls in w.classes

proc addClass*(w: Widget, cls: string) =
  if cls not in w.classes:
    w.classes.incl(cls)
    w.layoutVarsValid = false # Styles might change layout

proc removeClass*(w: Widget, cls: string) =
  if cls in w.classes:
    w.classes.excl(cls)
    w.layoutVarsValid = false

proc setAttribute*(w: Widget, key, value: string) =
  w.attributes[key] = value
  if key in ["margin", "layout", "flex-direction", "box-anchor", "left", "top", "right", "bottom"]:
    w.layoutVarsValid = false

# --- Layout Attribute Parsing ---

proc updateLayoutVars*(w: Widget) =
  if w.layoutVarsValid: return

  # Default margins
  w.margins = [0f32, 0, 0, 0]
  if w.attributes.hasKey("margin"):
    let parts = w.attributes["margin"].splitWhitespace()
    if parts.len == 1:
      let v = parts[0].parseFloat.float32
      w.margins = [v, v, v, v]
    elif parts.len == 2:
      let v = parts[0].parseFloat.float32
      let h = parts[1].parseFloat.float32
      w.margins = [h, v, h, v] # left top right bottom? In C++ it was ltrb

  # Flags
  w.layContain = 0
  let layoutAttr = w.attributes.getOrDefault("layout", "")
  if layoutAttr != "":
    w.layContain = 0x40000000u32 # LAYX_HASLAYOUT
    if layoutAttr == "box": w.layContain = w.layContain or uint32(LAY_LAYOUT)
    elif layoutAttr == "flex": w.layContain = w.layContain or uint32(LAY_FLEX)

    let flexDir = w.attributes.getOrDefault("flex-direction", "row")
    if flexDir == "row": w.layContain = w.layContain or uint32(LAY_ROW)
    elif flexDir == "column": w.layContain = w.layContain or uint32(LAY_COLUMN)

  w.layBehave = 0
  let anchor = w.attributes.getOrDefault("box-anchor", "")
  if anchor != "":
    if "fill" in anchor: w.layBehave = w.layBehave or uint32(LAY_FILL)
    if "left" in anchor: w.layBehave = w.layBehave or uint32(LAY_LEFT)
    if "top" in anchor: w.layBehave = w.layBehave or uint32(LAY_TOP)
    if "right" in anchor: w.layBehave = w.layBehave or uint32(LAY_RIGHT)
    if "bottom" in anchor: w.layBehave = w.layBehave or uint32(LAY_BOTTOM)

  w.layoutVarsValid = true

# --- Widget Hierarchy ---

proc newWidget*(node: SvgNode): Widget =
  new(result)
  result.node = node
  result.enabled = true
  result.visible = true
  result.layoutId = LayInvalidId
  result.children = @[]
  result.classes = initHashSet[string]()
  result.attributes = initTable[string, string]()
  result.layoutTransform = mat3()

proc addChild*(parent: Widget, child: Widget) =
  parent.children.add(child)
  child.parent = parent
  # In retained mode, we also update the SvgNode tree
  if parent.node of SvgGroup:
    SvgGroup(parent.node).children.add(child.node)

proc removeFromParent*(w: Widget) =
  if w.parent != nil:
    let idx = w.parent.children.find(w)
    if idx != -1: w.parent.children.delete(idx)
    if w.parent.node of SvgGroup:
      let nidx = SvgGroup(w.parent.node).children.find(w.node)
      if nidx != -1: SvgGroup(w.parent.node).children.delete(nidx)
    w.parent = nil

# --- Hit Testing ---

proc contains*(w: Widget, p: Vec2): bool =
  p.x >= w.computedRect.x and p.x <= w.computedRect.x + w.computedRect.w and
  p.y >= w.computedRect.y and p.y <= w.computedRect.y + w.computedRect.h

proc widgetAt*(w: Widget, p: Vec2): Widget =
  if not w.visible or not w.enabled: return nil

  # Check children in reverse order (top-most first)
  for i in countdown(w.children.len - 1, 0):
    let child = w.children[i]
    let hit = child.widgetAt(p)
    if hit != nil: return hit

  # Check self
  if w.contains(p): return w
  return nil

# --- Event System ---

proc dispatchEvent*(gui: SvgGui, w: Widget, event: var GuiEvent): bool =
  if w == nil or not w.enabled: return false

  # Event Filter (Capture Phase)
  # Actually, ugui filters walk up then call from top down
  var filterChain: seq[Widget] = @[]
  var curr = w
  while curr != nil:
    if curr.eventFilter != nil: filterChain.add(curr)
    curr = curr.parent

  for i in countdown(filterChain.len - 1, 0):
    if filterChain[i].eventFilter(gui, w, event): return true

  # Normal dispatch (Bubble Phase)
  curr = w
  while curr != nil:
    if curr.onEvent != nil:
      if curr.onEvent(curr, event): return true
    curr = curr.parent
  return false

proc handleWindyEvent*(gui: SvgGui, win: Window, event: windy.Event) =
  var guiEv = GuiEvent(timestamp: epochTime())
  case event.kind
  of ButtonDown:
    guiEv.kind = evMouseDown
    guiEv.pos = event.pos
    guiEv.button = event.button
    let hit = win.widgetAt(event.pos)
    if hit != nil:
      gui.setPressed(hit)
      discard gui.dispatchEvent(hit, guiEv)
  of ButtonUp:
    guiEv.kind = evMouseUp
    guiEv.pos = event.pos
    guiEv.button = event.button
    if gui.pressedWidget != nil:
      discard gui.dispatchEvent(gui.pressedWidget, guiEv)
      gui.pressedWidget = nil
  of MouseMove:
    guiEv.kind = evMouseMove
    guiEv.pos = event.pos
    let hit = win.widgetAt(event.pos)
    # Hover management
    if hit != gui.hoveredWidget:
      if gui.hoveredWidget != nil:
        var leaveEv = GuiEvent(kind: evMouseLeave, pos: event.pos)
        discard gui.dispatchEvent(gui.hoveredWidget, leaveEv)
      gui.hoveredWidget = hit
      if hit != nil:
        var enterEv = GuiEvent(kind: evMouseEnter, pos: event.pos)
        discard gui.dispatchEvent(hit, enterEv)

    if gui.pressedWidget != nil:
      discard gui.dispatchEvent(gui.pressedWidget, guiEv)
    elif hit != nil:
      discard gui.dispatchEvent(hit, guiEv)
  of Scroll:
    guiEv.kind = evScroll
    guiEv.delta = event.delta
    let hit = win.widgetAt(gui.prevFingerPos) # Use last mouse pos
    if hit != nil:
      discard gui.dispatchEvent(hit, guiEv)
  else: discard

# --- Focus & Pressed ---

proc setFocused*(gui: SvgGui, widget: Widget, reason: FocusReason = ReasonNone) =
  var target = widget
  while target != nil and not (target.isFocusable and target.enabled):
    target = target.parent

  if gui.focusedWidget == target: return

  if gui.focusedWidget != nil:
    var ev = GuiEvent(kind: evFocusLost)
    discard gui.focusedWidget.onEvent(gui.focusedWidget, ev)

  gui.focusedWidget = target
  if target != nil:
    var ev = GuiEvent(kind: evFocusGained)
    discard target.onEvent(target, ev)

proc setPressed*(gui: SvgGui, widget: Widget) =
  gui.pressedWidget = if widget != nil: widget.getPressedGroupContainer() else: nil
  gui.setFocused(widget, ReasonPressed)

proc onHideWidget*(gui: SvgGui, widget: Widget) =
  if gui.hoveredWidget != nil and gui.hoveredWidget.isDescendantOf(widget):
    gui.hoveredWidget = nil
  if gui.pressedWidget != nil and gui.pressedWidget.isDescendantOf(widget):
    gui.pressedWidget = nil
  if gui.focusedWidget != nil and gui.focusedWidget.isDescendantOf(widget):
    gui.focusedWidget = nil
  # Also handle menu stack
  while gui.menuStack.len > 0 and gui.menuStack[^1].isDescendantOf(widget):
    let menu = gui.menuStack.pop()
    menu.visible = false

# --- Lifecycle ---

proc prepareLayout*(ctx: var LayContext, w: Widget): LayId =
  w.updateLayoutVars()
  let id = ctx.item()
  w.layoutId = id

  ctx.setMargins(id, w.margins)
  ctx.setContain(id, w.layContain)
  ctx.setBehave(id, w.layBehave)

  if w.onPrepareLayout != nil:
    let b = w.onPrepareLayout(w)
    if b.w > 0 or b.h > 0:
      ctx.setSize(id, [b.w, b.h])

  for child in w.children:
    if child.visible:
      let cid = ctx.prepareLayout(child)
      ctx.insert(id, cid)
  return id

proc applyLayout*(ctx: var LayContext, w: Widget) =
  if w.layoutId != LayInvalidId:
    let r = ctx.getRect(w.layoutId)
    let dest = rect(r[0], r[1], r[2], r[3])
    let src = w.computedRect

    if w.onApplyLayout != nil:
      if w.onApplyLayout(w, src, dest):
        # Hook handled it
        discard

    w.computedRect = dest

  for child in w.children:
    ctx.applyLayout(child)

proc newSvgGui*(): SvgGui =
  new(result)
  result.layoutCtx.initContext()
  result.windows = @[]
  result.menuStack = @[]
  result.timers = @[]

proc processTimers*(gui: SvgGui) =
  let now = epochTime()
  var i = 0
  while i < gui.timers.len:
    if gui.timers[i].nextTick <= now:
      let period = if gui.timers[i].callback != nil:
                     gui.timers[i].callback()
                   else:
                     var ev = GuiEvent(kind: evTimer)
                     if gui.dispatchEvent(gui.timers[i].widget, ev):
                       gui.timers[i].period
                     else: 0
      if period <= 0:
        gui.timers.delete(i)
        continue
      else:
        gui.timers[i].nextTick = now + period.float / 1000.0
    i += 1

proc setTimer*(gui: SvgGui, msec: int, widget: Widget, callback: TimerCallback = nil): ptr Timer =
  var t = Timer(period: msec, widget: widget, callback: callback)
  t.nextTick = epochTime() + msec.float / 1000.0
  gui.timers.add(t)
  return addr gui.timers[^1]
