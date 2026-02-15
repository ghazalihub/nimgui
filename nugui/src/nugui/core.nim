import pixie, windy, vmath, vmath/rects, tables, sets, layout, times, os

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
    layoutId*: LayId
    margins*: LayVec4
    layContain*: uint32
    layBehave*: uint32
    onEvent*: proc(w: Widget, event: GuiEvent): bool {.gcsafe.}

    isFocusable*: bool
    isPressedGroupContainer*: bool
    layoutTransform*: Mat3
    computedRect*: Rect
    layoutIsolate*: bool
    layoutVarsValid*: bool
    attributes*: Table[string, string]

  Window* = ref object of Widget
    windyWindow*: windy.Window
    gui*: SvgGui
    absPosNodes*: seq[Widget]

  SvgGui* = ref object
    windows*: seq[Window]
    layoutCtx*: LayContext
    pressedWidget*: Widget
    hoveredWidget*: Widget
    focusedWidget*: Widget
    menuStack*: seq[Widget]
    lastClosedMenu*: Widget

    # Input state
    prevFingerPos*: Vec2
    totalFingerDist*: float32
    fingerUpDnTime*: float
    fingerClicks*: int
    flingV*: Vec2

    timers*: seq[Timer]
    inputScale*: float32
    paintScale*: float32

proc newWidget*(node: SvgNode): Widget =
  new(result)
  result.node = node
  result.enabled = true
  result.visible = true
  result.layoutId = LayInvalidId
  result.children = @[]
  result.layoutTransform = mat3()
  result.layoutVarsValid = false
  result.attributes = initTable[string, string]()

proc newSvgGui*(): SvgGui =
  new(result)
  result.windows = @[]
  result.layoutCtx.initContext()
  result.menuStack = @[]
  result.timers = @[]
  result.inputScale = 1.0
  result.paintScale = 1.0

proc addChild*(parent: Widget, child: Widget) =
  parent.children.add(child)
  child.parent = parent
  if parent.node of SvgGroup:
    SvgGroup(parent.node).children.add(child.node)

proc isDescendantOf*(w: Widget, parent: Widget): bool =
  var curr = w
  while curr != nil:
    if curr == parent: return true
    curr = curr.parent
  return false

proc getPressedGroupContainer(w: Widget): Widget =
  var container = w
  var curr = w
  while curr.parent != nil:
    curr = curr.parent
    if curr.isPressedGroupContainer and curr.visible:
      container = curr
  return container

proc setFocused*(gui: SvgGui, widget: Widget, reason: FocusReason = ReasonNone) =
  var target = widget
  while target != nil and not (target.isFocusable and target.enabled):
    target = target.parent

  if gui.focusedWidget == target: return

  if gui.focusedWidget != nil:
    discard gui.focusedWidget.onEvent(gui.focusedWidget, GuiEvent(kind: evFocusLost))

  gui.focusedWidget = target
  if target != nil:
    discard target.onEvent(target, GuiEvent(kind: evFocusGained))

proc setPressed*(gui: SvgGui, widget: Widget) =
  gui.pressedWidget = if widget != nil: widget.getPressedGroupContainer() else: nil
  gui.setFocused(widget, ReasonPressed)

proc widgetAt*(w: Widget, p: Vec2): Widget =
  if not w.visible: return nil

  # Check children in reverse order (top-most first)
  for i in countdown(w.children.len - 1, 0):
    let child = w.children[i]
    let hit = child.widgetAt(p)
    if hit != nil: return hit

  # Check self
  if p.x >= w.computedRect.x and p.x <= w.computedRect.x + w.computedRect.w and
     p.y >= w.computedRect.y and p.y <= w.computedRect.y + w.computedRect.h:
    return w
  return nil

proc dispatchEvent*(gui: SvgGui, w: Widget, event: GuiEvent): bool =
  if w == nil or not w.enabled: return false
  var curr = w
  while curr != nil:
    if curr.onEvent != nil:
      if curr.onEvent(curr, event):
        return true
    curr = curr.parent
  return false

proc updateGestures(gui: SvgGui, event: GuiEvent) =
  let t = epochTime()
  if event.kind == evMouseDown:
    gui.flingV = vec2(0, 0)
    gui.fingerClicks = if t - gui.fingerUpDnTime < 0.4 and event.pos.dist(gui.prevFingerPos) < 32:
                         gui.fingerClicks + 1
                       else: 1
    gui.totalFingerDist = 0
    gui.fingerUpDnTime = t
    gui.lastClosedMenu = nil
  elif event.kind == evMouseMove:
    gui.totalFingerDist += event.pos.dist(gui.prevFingerPos)
    if gui.totalFingerDist >= 20 or t - gui.fingerUpDnTime >= 0.4:
      gui.fingerClicks = 0
  elif event.kind == evMouseUp:
    let dt = (t - gui.fingerUpDnTime).float32
    if gui.totalFingerDist > 40 and dt > 0.03:
      gui.flingV = (event.pos - gui.prevFingerPos) / dt
    if gui.totalFingerDist >= 20 or t - gui.fingerUpDnTime >= 0.4:
      gui.fingerClicks = 0
  gui.prevFingerPos = event.pos

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
        discard gui.dispatchEvent(gui.hoveredWidget, GuiEvent(kind: evMouseLeave))
      gui.hoveredWidget = hit
      if hit != nil:
        discard gui.dispatchEvent(hit, GuiEvent(kind: evMouseEnter))
    if gui.pressedWidget != nil:
      discard gui.dispatchEvent(gui.pressedWidget, guiEv)
    elif hit != nil:
      discard gui.dispatchEvent(hit, guiEv)
  else:
    discard

proc processTimers*(gui: SvgGui) =
  let now = epochTime()
  var i = 0
  while i < gui.timers.len:
    if gui.timers[i].nextTick <= now:
      let period = if gui.timers[i].callback != nil:
                     gui.timers[i].callback()
                   else:
                     if gui.dispatchEvent(gui.timers[i].widget, GuiEvent(kind: evTimer)):
                       gui.timers[i].period
                     else: 0
      if period <= 0:
        gui.timers.delete(i)
        continue
      else:
        gui.timers[i].nextTick = now + period.float / 1000.0
    i += 1

proc setTimer*(gui: SvgGui, msec: int, widget: Widget, callback: TimerCallback = nil): ptr Timer =
  var timer = Timer(period: msec, widget: widget, callback: callback)
  timer.nextTick = epochTime() + msec.float / 1000.0
  gui.timers.add(timer)
  return addr gui.timers[^1]

# --- Layout ---

proc prepareLayout*(ctx: var LayContext, w: Widget): LayId =
  let id = ctx.item()
  w.layoutId = id
  # Map attributes to lay flags
  # ...
  for child in w.children:
    if child.visible:
      let cid = ctx.prepareLayout(child)
      ctx.insert(id, cid)
  return id

proc applyLayout*(ctx: var LayContext, w: Widget) =
  if w.layoutId != LayInvalidId:
    let r = ctx.getRect(w.layoutId)
    w.computedRect = rect(r[0], r[1], r[2], r[3])
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
