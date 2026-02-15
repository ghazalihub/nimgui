import pixie, windy, vmath, vmath/rects, tables, sets, layout, times, os, strutils, opengl

export windy.Key, windy.MouseButton, windy.Modifier, windy.mCtrl, windy.mShift, windy.mAlt

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
    key*: Key
    keyCode*: Key
    mods*: set[Modifier]
    delta*: Vec2
    timestamp*: float
    touchId*: int
    fingerId*: int
    pressure*: float32
    clicks*: int
    text*: string

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
    layoutIsolate*: bool
    layoutVarsValid*: bool
    layoutTransform*: Mat3
    computedRect*: Rect
    classes*: HashSet[string]
    attributes*: Table[string, string]
    onEvent*: proc(w: Widget, event: GuiEvent): bool {.gcsafe.}
    eventFilter*: proc(gui: SvgGui, w: Widget, event: var GuiEvent): bool {.gcsafe.}
    onPrepareLayout*: proc(w: Widget): Rect {.gcsafe.}
    onApplyLayout*: proc(w: Widget, src, dest: Rect): bool {.gcsafe.}
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
    texture*: uint32

  SvgGui* = ref object
    windows*: seq[Window]
    layoutCtx*: LayContext
    pressedWidget*: Widget
    hoveredWidget*: Widget
    focusedWidget*: Widget
    menuStack*: seq[Widget]
    lastClosedMenu*: Widget
    timers*: seq[Timer]
    inputScale*: float32
    paintScale*: float32

proc setFocused*(gui: SvgGui, widget: Widget, reason: FocusReason = ReasonNone)
proc setPressed*(gui: SvgGui, widget: Widget)
proc onHideWidget*(gui: SvgGui, widget: Widget)
proc isDescendantOf*(w: Widget, parent: Widget): bool

proc newWidget*(node: SvgNode = nil): Widget =
  new(result); result.node = if node != nil: node else: newSvgGroup()
  result.enabled = true; result.visible = true; result.layoutId = LayInvalidId
  result.children = @[]; result.classes = initHashSet[string](); result.attributes = initTable[string, string]()
  result.layoutTransform = mat3(); result.isDirty = true

proc addChild*(parent: Widget, child: Widget) =
  parent.children.add(child); child.parent = parent
  if parent.node of SvgGroup: SvgGroup(parent.node).children.add(child.node)
  parent.isDirty = true

proc getPressedGroupContainer(w: Widget): Widget =
  var curr = w; while curr.parent != nil: (if curr.isPressedGroupContainer and curr.visible: return curr; curr = curr.parent)
  return w

proc contains*(w: Widget, p: Vec2): bool =
  p.x >= w.computedRect.x and p.x <= w.computedRect.x + w.computedRect.w and
  p.y >= w.computedRect.y and p.y <= w.computedRect.y + w.computedRect.h

proc widgetAt*(w: Widget, p: Vec2): Widget =
  if not w.visible or not w.enabled: return nil
  for i in countdown(w.children.len - 1, 0): (let hit = w.children[i].widgetAt(p); if hit != nil: return hit)
  if w.contains(p): return w
  return nil

proc dispatchEvent*(gui: SvgGui, w: Widget, event: var GuiEvent): bool =
  if w == nil or not w.enabled: return false
  var curr = w; while curr != nil: (if curr.onEvent != nil: (if curr.onEvent(curr, event): return true); curr = curr.parent)
  return false

proc handleWindyEvent*(gui: SvgGui, win: Window, event: windy.Event) =
  var guiEv = GuiEvent(timestamp: epochTime())
  case event.kind
  of ButtonDown:
    guiEv.kind = evMouseDown; guiEv.pos = event.pos; guiEv.button = event.button
    let hit = win.widgetAt(event.pos); if hit != nil: (gui.setPressed(hit); discard gui.dispatchEvent(hit, guiEv))
  of ButtonUp:
    guiEv.kind = evMouseUp; guiEv.pos = event.pos; guiEv.button = event.button
    if gui.pressedWidget != nil: (discard gui.dispatchEvent(gui.pressedWidget, guiEv); gui.pressedWidget = nil)
  of MouseMove:
    guiEv.kind = evMouseMove; guiEv.pos = event.pos; let hit = win.widgetAt(event.pos)
    if hit != gui.hoveredWidget:
      if gui.hoveredWidget != nil: (var leaveEv = GuiEvent(kind: evMouseLeave, pos: event.pos); discard gui.dispatchEvent(gui.hoveredWidget, leaveEv))
      gui.hoveredWidget = hit; if hit != nil: (var enterEv = GuiEvent(kind: evMouseEnter, pos: event.pos); discard gui.dispatchEvent(hit, enterEv))
    if gui.pressedWidget != nil: discard gui.dispatchEvent(gui.pressedWidget, guiEv)
    elif hit != nil: discard gui.dispatchEvent(hit, guiEv)
  of KeyDown:
    guiEv.kind = evKeyDown; guiEv.key = event.key; guiEv.keyCode = event.key; guiEv.mods = event.modifiers
    if gui.focusedWidget != nil: discard gui.dispatchEvent(gui.focusedWidget, guiEv)
  of TextInput:
    guiEv.kind = evTextInput; guiEv.text = event.text
    if gui.focusedWidget != nil: discard gui.dispatchEvent(gui.focusedWidget, guiEv)
  else: discard

proc setFocused*(gui: SvgGui, widget: Widget, reason: FocusReason = ReasonNone) =
  if gui.focusedWidget == widget: return
  if gui.focusedWidget != nil: (var ev = GuiEvent(kind: evFocusLost); discard gui.focusedWidget.onEvent(gui.focusedWidget, ev))
  gui.focusedWidget = widget; if widget != nil: (var ev = GuiEvent(kind: evFocusGained); discard widget.onEvent(widget, ev))

proc focusWidget*(win: Window, widget: Widget) = win.gui.setFocused(widget, ReasonPressed)

proc setPressed*(gui: SvgGui, widget: Widget) =
  gui.pressedWidget = if widget != nil: widget.getPressedGroupContainer() else: nil
  gui.setFocused(widget, ReasonPressed)

proc isDescendantOf*(w: Widget, parent: Widget): bool =
  var curr = w; while curr != nil: (if curr == parent: return true; curr = curr.parent)
  return false

proc onHideWidget*(gui: SvgGui, widget: Widget) =
  if gui.hoveredWidget != nil and gui.hoveredWidget.isDescendantOf(widget): gui.hoveredWidget = nil
  if gui.pressedWidget != nil and gui.pressedWidget.isDescendantOf(widget): gui.pressedWidget = nil
  if gui.focusedWidget != nil and gui.focusedWidget.isDescendantOf(widget): gui.focusedWidget = nil

proc processTimers*(gui: SvgGui) =
  let now = epochTime(); var i = 0
  while i < gui.timers.len:
    if gui.timers[i].nextTick <= now:
      let period = if gui.timers[i].callback != nil: gui.timers[i].callback() else: (var ev = GuiEvent(kind: evTimer); if gui.dispatchEvent(gui.timers[i].widget, ev): gui.timers[i].period else: 0)
      if period <= 0: (gui.timers.delete(i); continue) else: gui.timers[i].nextTick = now + period.float / 1000.0
    i += 1

proc setTimer*(gui: SvgGui, msec: int, widget: Widget, callback: TimerCallback = nil): int =
  var t = Timer(period: msec, widget: widget, callback: callback, nextTick: epochTime() + msec.float / 1000.0)
  gui.timers.add(t); return gui.timers.len - 1

proc parseMargins*(w: Widget) =
  w.margins = [0f32, 0, 0, 0]; let m = w.attributes.getOrDefault("margin", "")
  if m == "": return
  let p = m.splitWhitespace(); if p.len == 1: (let v = p[0].parseFloat.float32; w.margins = [v, v, v, v])
  elif p.len == 2: (let v = p[0].parseFloat.float32; let h = p[1].parseFloat.float32; w.margins = [h, v, h, v])
  elif p.len == 4: w.margins = [p[3].parseFloat.float32, p[0].parseFloat.float32, p[1].parseFloat.float32, p[2].parseFloat.float32]

proc updateLayoutVars*(w: Widget) =
  if w.layoutVarsValid: return
  w.parseMargins(); let layout = w.attributes.getOrDefault("layout", ""); w.layContain = 0
  if layout != "": (w.layContain = 0x40000000u32; if layout == "box": w.layContain = w.layContain or uint32(LAY_LAYOUT) elif layout == "flex": w.layContain = w.layContain or uint32(LAY_FLEX); let dir = w.attributes.getOrDefault("flex-direction", "row"); if dir == "row": w.layContain = w.layContain or uint32(LAY_ROW) elif dir == "column": w.layContain = w.layContain or uint32(LAY_COLUMN))
  let anchor = w.attributes.getOrDefault("box-anchor", ""); w.layBehave = 0
  if anchor != "": (if "fill" in anchor: w.layBehave = w.layBehave or uint32(LAY_FILL); if "left" in anchor: w.layBehave = w.layBehave or uint32(LAY_LEFT); if "top" in anchor: w.layBehave = w.layBehave or uint32(LAY_TOP); if "right" in anchor: w.layBehave = w.layBehave or uint32(LAY_RIGHT); if "bottom" in anchor: w.layBehave = w.layBehave or uint32(LAY_BOTTOM))
  w.layoutVarsValid = true

proc prepareLayout*(ctx: var LayContext, w: Widget): LayId =
  w.updateLayoutVars(); let id = ctx.item(); w.layoutId = id; ctx.setMargins(id, w.margins); ctx.setContain(id, w.layContain); ctx.setBehave(id, w.layBehave)
  if "width" in w.attributes: ctx.setSize(id, [w.attributes["width"].parseFloat.float32, 0])
  if "height" in w.attributes: (var s = ctx.getSize(id); s[1] = w.attributes["height"].parseFloat.float32; ctx.setSize(id, s))
  for child in w.children: (if child.visible: ctx.insert(id, ctx.prepareLayout(child)))
  return id

proc applyLayout*(ctx: var LayContext, w: Widget) =
  if w.layoutId != LayInvalidId: (let r = ctx.getRect(w.layoutId); w.computedRect = rect(r[0], r[1], r[2], r[3]); if w.node of SvgRect: (let n = SvgRect(w.node); n.x = r[0]; n.y = r[1]; n.width = r[2]; n.height = r[3]) elif w.node of SvgText: (let n = SvgText(w.node); n.x = r[0]; n.y = r[1] + r[3] * 0.7))
  for child in w.children: ctx.applyLayout(child)

proc newSvgGui*(): SvgGui = (new(result); result.layoutCtx = newLayoutContext(); result.windows = @[]; result.timers = @[])
