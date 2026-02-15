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
    data*: pointer

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

    # Layout state
    layoutId*: LayId
    margins*: LayVec4
    layContain*: uint32
    layBehave*: uint32
    layoutIsolate*: bool
    layoutVarsValid*: bool
    layoutTransform*: Mat3
    computedRect*: Rect

    # State tracking
    classes*: HashSet[string]
    attributes*: Table[string, string]

    # Callbacks
    onEvent*: proc(w: Widget, event: GuiEvent): bool {.gcsafe.}
    eventFilter*: proc(gui: SvgGui, w: Widget, event: var GuiEvent): bool {.gcsafe.}
    onPrepareLayout*: proc(w: Widget): Rect {.gcsafe.}
    onApplyLayout*: proc(w: Widget, src, dest: Rect): bool {.gcsafe.}

    # Behavior flags
    isFocusable*: bool
    isPressedGroupContainer*: bool
    isDirty*: bool

  Window* = ref object of Widget
    windyWindow*: windy.Window
    gui*: SvgGui
    focusedWidget*: Widget
    absPosNodes*: seq[Widget]
    winBounds*: Rect
    title*: string
    modalChild*: Window
    parentWindow*: Window

  SvgGui* = ref object
    windows*: seq[Window]
    layoutCtx*: LayContext
    pressedWidget*: Widget
    hoveredWidget*: Widget
    focusedWidget*: Widget
    menuStack*: seq[Widget]
    lastClosedMenu*: Widget

    # Input/Gesture state
    prevFingerPos*: Vec2
    totalFingerDist*: float32
    fingerUpDnTime*: float
    fingerClicks*: int
    flingV*: Vec2
    multiTouchActive*: bool

    timers*: seq[Timer]
    inputScale*: float32
    paintScale*: float32

    # Debugging
    debugLayout*: bool
    debugDirty*: bool

# --- Forward Declarations ---
proc setFocused*(gui: SvgGui, widget: Widget, reason: FocusReason = ReasonNone)
proc setPressed*(gui: SvgGui, widget: Widget)
proc onHideWidget*(gui: SvgGui, widget: Widget)
proc isDescendantOf*(w: Widget, parent: Widget): bool

# --- Widget Logic ---

proc newWidget*(node: SvgNode = nil): Widget =
  new(result)
  result.node = if node != nil: node else: newSvgGroup()
  result.enabled = true
  result.visible = true
  result.layoutId = LayInvalidId
  result.children = @[]
  result.classes = initHashSet[string]()
  result.attributes = initTable[string, string]()
  result.layoutTransform = mat3()
  result.isDirty = true

proc addChild*(parent: Widget, child: Widget) =
  if child.parent != nil:
    # Error or handle relocation
    discard
  parent.children.add(child)
  child.parent = parent
  if parent.node of SvgGroup:
    SvgGroup(parent.node).children.add(child.node)
  parent.isDirty = true

proc getPressedGroupContainer(w: Widget): Widget =
  var container = w
  var curr = w
  while curr.parent != nil:
    curr = curr.parent
    if curr.isPressedGroupContainer and curr.visible:
      container = curr
  return container

# --- Hit Testing ---

proc contains*(w: Widget, p: Vec2): bool =
  # p is relative to window
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

  # Event Filter walk
  var filters: seq[Widget] = @[]
  var curr = w
  while curr != nil:
    if curr.eventFilter != nil: filters.add(curr)
    curr = curr.parent

  for i in countdown(filters.len - 1, 0):
    if filters[i].eventFilter(gui, w, event): return true

  # Bubble up
  curr = w
  while curr != nil:
    if curr.onEvent != nil:
      if curr.onEvent(curr, event): return true
    curr = curr.parent
  return false

proc updateGestures(gui: SvgGui, event: var GuiEvent) =
  let t = epochTime()
  if event.kind == evMouseDown:
    gui.flingV = vec2(0, 0)
    if t - gui.fingerUpDnTime < 0.4 and event.pos.dist(gui.prevFingerPos) < 32:
      gui.fingerClicks += 1
    else:
      gui.fingerClicks = 1
    gui.totalFingerDist = 0
    gui.fingerUpDnTime = t
  elif event.kind == evMouseMove:
    gui.totalFingerDist += event.pos.dist(gui.prevFingerPos)
    if gui.totalFingerDist >= 20 or t - gui.fingerUpDnTime >= 0.4:
      gui.fingerClicks = 0
  elif event.kind == evMouseUp:
    let dt = (t - gui.fingerUpDnTime).float32
    if gui.totalFingerDist > 40 and dt > 0.03:
      gui.flingV = (event.pos - gui.prevFingerPos) / dt
    # clicks preserved for Up event
  gui.prevFingerPos = event.pos
  event.clicks = gui.fingerClicks

proc handleWindyEvent*(gui: SvgGui, win: Window, event: windy.Event) =
  var guiEv = GuiEvent(timestamp: epochTime())
  case event.kind
  of ButtonDown:
    guiEv.kind = evMouseDown
    guiEv.pos = event.pos
    guiEv.button = event.button
    gui.updateGestures(guiEv)
    let hit = win.widgetAt(event.pos)
    if hit != nil:
      gui.setPressed(hit)
      discard gui.dispatchEvent(hit, guiEv)
  of ButtonUp:
    guiEv.kind = evMouseUp
    guiEv.pos = event.pos
    guiEv.button = event.button
    gui.updateGestures(guiEv)
    if gui.pressedWidget != nil:
      discard gui.dispatchEvent(gui.pressedWidget, guiEv)
      gui.pressedWidget = nil
  of MouseMove:
    guiEv.kind = evMouseMove
    guiEv.pos = event.pos
    gui.updateGestures(guiEv)
    let hit = win.widgetAt(event.pos)

    if hit != gui.hoveredWidget:
      if gui.hoveredWidget != nil:
        var leaveEv = GuiEvent(kind: evMouseLeave, pos: event.pos, timestamp: guiEv.timestamp)
        discard gui.dispatchEvent(gui.hoveredWidget, leaveEv)
      gui.hoveredWidget = hit
      if hit != nil:
        var enterEv = GuiEvent(kind: evMouseEnter, pos: event.pos, timestamp: guiEv.timestamp)
        discard gui.dispatchEvent(hit, enterEv)

    if gui.pressedWidget != nil:
      discard gui.dispatchEvent(gui.pressedWidget, guiEv)
    elif hit != nil:
      discard gui.dispatchEvent(hit, guiEv)
  of Scroll:
    guiEv.kind = evScroll
    guiEv.delta = event.delta
    let hit = win.widgetAt(gui.prevFingerPos)
    if hit != nil:
      discard gui.dispatchEvent(hit, guiEv)
  else: discard

# --- Focus/Pressed ---

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

proc isDescendantOf*(w: Widget, parent: Widget): bool =
  var curr = w
  while curr != nil:
    if curr == parent: return true
    curr = curr.parent
  return false

proc onHideWidget*(gui: SvgGui, widget: Widget) =
  if gui.hoveredWidget != nil and gui.hoveredWidget.isDescendantOf(widget):
    gui.hoveredWidget = nil
  if gui.pressedWidget != nil and gui.pressedWidget.isDescendantOf(widget):
    gui.pressedWidget = nil
  if gui.focusedWidget != nil and gui.focusedWidget.isDescendantOf(widget):
    gui.focusedWidget = nil

  # Pop menus
  while gui.menuStack.len > 0 and gui.menuStack[^1].isDescendantOf(widget):
    let menu = gui.menuStack.pop()
    menu.visible = false

# --- Timers ---

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

proc setTimer*(gui: SvgGui, msec: int, widget: Widget, callback: TimerCallback = nil): int =
  var t = Timer(period: msec, widget: widget, callback: callback)
  t.nextTick = epochTime() + msec.float / 1000.0
  gui.timers.add(t)
  return gui.timers.len - 1

proc removeTimer*(gui: SvgGui, timerIdx: int) =
  if timerIdx >= 0 and timerIdx < gui.timers.len:
    gui.timers.delete(timerIdx)

proc removeTimers*(gui: SvgGui, widget: Widget) =
  var i = 0
  while i < gui.timers.len:
    if gui.timers[i].widget == widget:
      gui.timers.delete(i)
    else:
      i += 1

# --- Animation Helper ---

type
  Animation* = ref object
    startTime*: float
    duration*: float
    onUpdate*: proc(t: float32) {.gcsafe.}
    onComplete*: proc() {.gcsafe.}

proc startAnimation*(gui: SvgGui, duration: float, onUpdate: proc(t: float32) {.gcsafe.}, onComplete: proc() {.gcsafe.} = nil) =
  let anim = Animation(startTime: epochTime(), duration: duration, onUpdate: onUpdate, onComplete: onComplete)
  discard gui.setTimer(16, nil, proc(): int =
    let elapsed = epochTime() - anim.startTime
    let t = clamp((elapsed / anim.duration).float32, 0.0, 1.0)
    anim.onUpdate(t)
    if t >= 1.0:
      if anim.onComplete != nil: anim.onComplete()
      return 0 # Stop timer
    return 16 # Continue every 16ms (~60fps)
  )

# --- Layout Integration ---

proc parseMargins*(w: Widget) =
  w.margins = [0f32, 0, 0, 0]
  let m = w.attributes.getOrDefault("margin", "")
  if m != "":
    let p = m.splitWhitespace()
    if p.len == 1:
      let v = p[0].parseFloat.float32
      w.margins = [v, v, v, v]
    elif p.len == 2:
      let v = p[0].parseFloat.float32
      let h = p[1].parseFloat.float32
      w.margins = [h, v, h, v]
    elif p.len == 4:
      w.margins = [p[3].parseFloat.float32, p[0].parseFloat.float32, p[1].parseFloat.float32, p[2].parseFloat.float32]

proc updateLayoutVars*(w: Widget) =
  if w.layoutVarsValid: return
  w.parseMargins()

  let layout = w.attributes.getOrDefault("layout", "")
  w.layContain = 0
  if layout != "":
    w.layContain = 0x40000000u32 # HASLAYOUT
    if layout == "box": w.layContain = w.layContain or uint32(LAY_LAYOUT)
    elif layout == "flex": w.layContain = w.layContain or uint32(LAY_FLEX)

    let dir = w.attributes.getOrDefault("flex-direction", "row")
    if dir == "row": w.layContain = w.layContain or uint32(LAY_ROW)
    elif dir == "column": w.layContain = w.layContain or uint32(LAY_COLUMN)

    if w.attributes.getOrDefault("flex-wrap", "") == "wrap":
      w.layContain = w.layContain or uint32(LAY_WRAP)

    let justify = w.attributes.getOrDefault("justify-content", "")
    if justify == "flex-start": w.layContain = w.layContain or uint32(LAY_START)
    elif justify == "flex-end": w.layContain = w.layContain or uint32(LAY_END)
    elif justify == "center": w.layContain = w.layContain or uint32(LAY_MIDDLE)
    elif justify == "space-between": w.layContain = w.layContain or uint32(LAY_JUSTIFY)

  let anchor = w.attributes.getOrDefault("box-anchor", "")
  w.layBehave = 0
  if anchor != "":
    if "fill" in anchor: w.layBehave = w.layBehave or uint32(LAY_FILL)
    if "left" in anchor: w.layBehave = w.layBehave or uint32(LAY_LEFT)
    if "top" in anchor: w.layBehave = w.layBehave or uint32(LAY_TOP)
    if "right" in anchor: w.layBehave = w.layBehave or uint32(LAY_RIGHT)
    if "bottom" in anchor: w.layBehave = w.layBehave or uint32(LAY_BOTTOM)

  w.layoutVarsValid = true

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
      discard w.onApplyLayout(w, src, dest)

    w.computedRect = dest

    # Apply layout results to SVG nodes
    if w.node of SvgRect:
      let node = SvgRect(w.node)
      node.x = dest.x
      node.y = dest.y
      node.width = dest.w
      node.height = dest.h
    elif w.node of SvgText:
      let node = SvgText(w.node)
      node.x = dest.x
      node.y = dest.y + dest.h * 0.7 # Simple baseline adjustment
    # Groups handle positioning through parent transformations or recursion

  for child in w.children:
    ctx.applyLayout(child)

proc draw*(gui: SvgGui) =
  gui.processTimers()
  gui.layoutCtx.resetContext()
  for win in gui.windows:
    let rootId = gui.layoutCtx.prepareLayout(win)
    gui.layoutCtx.setSize(rootId, [win.windyWindow.size.x.float32, win.windyWindow.size.y.float32])
    gui.layoutCtx.runContext()
    gui.layoutCtx.applyLayout(win)
