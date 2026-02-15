import pixie, windy, vmath, vmath/rects, tables, sets, layout

type
  FocusReason* = enum
    ReasonNone, ReasonPressed, ReasonTab, ReasonWindow, ReasonMenu, ReasonHidden

  EventKind* = enum
    evClick, evMouseDown, evMouseUp, evMouseMove, evKeyDown, evKeyUp, evScroll,
    evMouseEnter, evMouseLeave, evFocusGained, evFocusLost, evTimer

  GuiEvent* = object
    kind*: EventKind
    pos*: Vec2
    button*: MouseButton
    keyCode*: KeyCode
    delta*: Vec2

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
    # Internal state
    isFocusable*: bool
    isPressedGroupContainer*: bool
    layoutTransform*: Mat3
    computedRect*: Rect

  SvgGui* = ref object
    windows*: seq[Window]
    layoutCtx*: LayContext
    pressedWidget*: Widget
    hoveredWidget*: Widget
    focusedWidget*: Widget

  Window* = ref object of Widget
    windyWindow*: windy.Window
    gui*: SvgGui
    absPosNodes*: seq[Widget]

proc newWidget*(node: SvgNode): Widget =
  new(result)
  result.node = node
  result.enabled = true
  result.visible = true
  result.layoutId = LayInvalidId
  result.children = @[]
  result.layoutTransform = mat3()

proc newSvgGui*(): SvgGui =
  new(result)
  result.windows = @[]
  result.layoutCtx.initContext()

proc addChild*(parent: Widget, child: Widget) =
  parent.children.add(child)
  child.parent = parent
  if parent.node of SvgGroup:
    SvgGroup(parent.node).children.add(child.node)

proc contains*(w: Widget, p: Vec2): bool =
  # Use computedRect for hit testing
  p.x >= w.computedRect.x and p.x <= w.computedRect.x + w.computedRect.w and
  p.y >= w.computedRect.y and p.y <= w.computedRect.y + w.computedRect.h

proc widgetAt*(w: Widget, p: Vec2): Widget =
  if not w.visible: return nil

  # Check children in reverse order (top-most first)
  for i in countdown(w.children.len - 1, 0):
    let child = w.children[i]
    let hit = child.widgetAt(p)
    if hit != nil: return hit

  # Check self
  if w.contains(p): return w
  return nil

proc setFocused*(gui: SvgGui, widget: Widget, reason: FocusReason = ReasonNone) =
  if gui.focusedWidget == widget: return

  if gui.focusedWidget != nil:
    discard gui.focusedWidget.onEvent(gui.focusedWidget, GuiEvent(kind: evFocusLost))

  gui.focusedWidget = widget
  if widget != nil:
    discard widget.onEvent(widget, GuiEvent(kind: evFocusGained))

proc handleWindyEvent*(gui: SvgGui, win: Window, event: windy.Event) =
  var guiEv: GuiEvent
  case event.kind
  of ButtonDown:
    guiEv = GuiEvent(kind: evMouseDown, pos: event.pos, button: event.button)
    let hit = win.widgetAt(event.pos)
    if hit != nil:
      gui.pressedWidget = hit
      gui.setFocused(hit, ReasonPressed)
      discard gui.dispatchEvent(hit, guiEv)
  of ButtonUp:
    guiEv = GuiEvent(kind: evMouseUp, pos: event.pos, button: event.button)
    if gui.pressedWidget != nil:
      discard gui.dispatchEvent(gui.pressedWidget, guiEv)
      gui.pressedWidget = nil
  of MouseMove:
    guiEv = GuiEvent(kind: evMouseMove, pos: event.pos)
    let hit = win.widgetAt(event.pos)
    if hit != gui.hoveredWidget:
      if gui.hoveredWidget != nil:
        discard gui.dispatchEvent(gui.hoveredWidget, GuiEvent(kind: evMouseLeave))
      gui.hoveredWidget = hit
      if hit != nil:
        discard gui.dispatchEvent(hit, GuiEvent(kind: evMouseEnter))
    if hit != nil:
      discard gui.dispatchEvent(hit, guiEv)
  else:
    discard

proc dispatchEvent*(gui: SvgGui, w: Widget, event: GuiEvent): bool =
  if not w.enabled: return false
  var curr = w
  while curr != nil:
    if curr.onEvent != nil:
      if curr.onEvent(curr, event):
        return true
    curr = curr.parent
  return false

# --- Rendering bridge (initial) ---
# Will be expanded in renderer.nim

proc processEvents*(gui: SvgGui) =
  for win in gui.windows:
    for event in win.windyWindow.events:
      gui.handleWindyEvent(win, event)

proc draw*(gui: SvgGui) =
  gui.layoutCtx.resetContext()
  for win in gui.windows:
    let rootId = gui.layoutCtx.prepareLayout(win)
    gui.layoutCtx.setSize(rootId, [win.windyWindow.size.x.float32, win.windyWindow.size.y.float32])
    gui.layoutCtx.runContext()
    gui.layoutCtx.applyLayout(win)
    # Rendering bridge call would go here
