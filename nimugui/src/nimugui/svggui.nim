import pixie, windy, vmath, chroma, std/[options, tables, sequtils, algorithm, times, strutils, math, os]
import layout

type
  FocusReason* = enum
    REASON_NONE = 0, REASON_PRESSED, REASON_TAB, REASON_WINDOW, REASON_MENU, REASON_HIDDEN

  Margins* = object
    left*, top*, right*, bottom*: float32

  # Forward declarations
  Widget* = ref object of RootObj
    gui*: SvgGui
    node*: Node
    layoutId*: lay_id
    layoutTransform*: Mat3
    enabled*: bool
    isPressedGroupContainer*: bool
    isFocusable*: bool
    layoutVarsValid*: bool
    layContain*: uint32
    layBehave*: uint32
    margins*: Margins
    handlers*: seq[proc(gui: SvgGui, event: Event): bool]
    eventFilter*: proc(gui: SvgGui, widget: Widget, event: Event): bool
    onApplyLayout*: proc(src, dest: Rect): bool

  Window* = ref object of Widget
    parentWindow*: Window
    currentModal*: Window
    focusedWidget*: Widget
    isModal*: bool
    winBounds*: Rect
    winTitle*: string
    absPosNodes*: seq[Widget]
    windyWindow*: windy.Window

  SvgGui* = ref object
    layoutCtx*: lay_context
    windows*: seq[Window]
    pressedWidget*: Widget
    hoveredWidget*: Widget
    nextInputWidget*: Widget
    currInputWidget*: Widget
    lastClosedMenu*: Widget
    menuStack*: seq[Widget]
    timers*: seq[Timer]
    inputScale*: float32
    paintScale*: float32
    prevFingerPos*: Vec2
    totalFingerDist*: float32
    fingerUpDnTime*: float64
    fingerClicks*: int
    multiTouchActive*: bool
    penDown*: bool
    flingV*: Vec2
    nodeToWidget*: Table[Node, Widget]
    pressEvent*: Event

  Timer* = ref object
    period*: int
    nextTick*: float64
    widget*: Widget
    callback*: proc(): int

const
  LAYX_HASLAYOUT* = 0x40000000'u32
  LAYX_REVERSE* = 0x20000000'u32

# Custom Event Kind (Internal)
const
  EV_ENTER* = uint32(0x9005)
  EV_LEAVE* = uint32(0x9006)
  EV_OUTSIDE_PRESSED* = uint32(0x9009)
  EV_OUTSIDE_MODAL* = uint32(0x9008)

# Extension for Event to support custom kinds
type
  GuiEvent* = object
    base*: Event
    kind*: uint32 # Using uint32 for custom kinds

proc getWidget*(gui: SvgGui, node: Node): Widget =
  if node == nil: return nil
  if not gui.nodeToWidget.hasKey(node):
    let w = Widget(node: node, gui: gui, layoutId: LAY_INVALID_ID, layoutTransform: mat3(), enabled: true)
    gui.nodeToWidget[node] = w
    return w
  return gui.nodeToWidget[node]

proc updateLayoutVars*(w: Widget) =
  let layoutAttr = w.node.attrs.getOrDefault("layout", "")
  w.layContain = 0
  if layoutAttr != "":
    w.layContain = LAYX_HASLAYOUT
    if layoutAttr == "flex": w.layContain = w.layContain or LAY_FLEX
    elif layoutAttr == "box": w.layContain = w.layContain or LAY_LAYOUT
    let flexDir = w.node.attrs.getOrDefault("flex-direction", "")
    if flexDir == "column": w.layContain = w.layContain or LAY_COLUMN
    elif flexDir == "row": w.layContain = w.layContain or LAY_ROW
    elif flexDir == "column-reverse": w.layContain = w.layContain or LAY_COLUMN or LAYX_REVERSE
    elif flexDir == "row-reverse": w.layContain = w.layContain or LAY_ROW or LAYX_REVERSE
    if w.node.attrs.getOrDefault("flex-wrap", "") == "wrap": w.layContain = w.layContain or LAY_WRAP
    let justify = w.node.attrs.getOrDefault("justify-content", "")
    if justify == "flex-start": w.layContain = w.layContain or LAY_START
    elif justify == "flex-end": w.layContain = w.layContain or LAY_END
    elif justify == "center": w.layContain = w.layContain or LAY_MIDDLE
    elif justify == "space-between": w.layContain = w.layContain or LAY_JUSTIFY

  w.layBehave = 0
  let anchor = w.node.attrs.getOrDefault("box-anchor", "")
  if anchor != "":
    if anchor == "fill": w.layBehave = w.layBehave or LAY_FILL
    else:
      if "left" in anchor or "hfill" in anchor: w.layBehave = w.layBehave or LAY_LEFT
      if "top" in anchor or "vfill" in anchor: w.layBehave = w.layBehave or LAY_TOP
      if "right" in anchor or "hfill" in anchor: w.layBehave = w.layBehave or LAY_RIGHT
      if "bottom" in anchor or "vfill" in anchor: w.layBehave = w.layBehave or LAY_BOTTOM

  let marginStr = w.node.attrs.getOrDefault("margin", "")
  if marginStr != "":
    let parts = marginStr.splitWhitespace()
    var m: array[4, float32] = [0.0f, 0.0, 0.0, 0.0]
    try:
      if parts.len == 1: let v = parts[0].parseFloat(); m = [v, v, v, v]
      elif parts.len == 2: let v = parts[0].parseFloat(); let h = parts[1].parseFloat(); m = [v, h, v, h]
      elif parts.len >= 4: m = [parts[0].parseFloat(), parts[1].parseFloat(), parts[2].parseFloat(), parts[3].parseFloat()]
    except: discard
    w.margins = Margins(top: m[0], right: m[1], bottom: m[2], left: m[3])
  w.layoutVarsValid = true

proc prepareLayout*(gui: SvgGui, w: Widget): lay_id =
  let id = lay_item(gui.layoutCtx)
  w.layoutId = id
  if not w.layoutVarsValid: w.updateLayoutVars()
  if (w.layContain and LAYX_HASLAYOUT) != 0:
    for childNode in w.node.children:
      if not childNode.visible or childNode.attrs.getOrDefault("position", "") == "absolute": continue
      let cw = gui.getWidget(childNode)
      if (w.layContain and LAYX_REVERSE) != 0: lay_push(gui.layoutCtx, id, gui.prepareLayout(cw))
      else: lay_insert(gui.layoutCtx, id, gui.prepareLayout(cw))
  let m = w.margins
  lay_set_margins_ltrb(gui.layoutCtx, id, m.left, m.top, m.right, m.bottom)
  lay_set_contain(gui.layoutCtx, id, w.layContain and LAY_ITEM_BOX_MASK)
  lay_set_behave(gui.layoutCtx, id, w.layBehave and LAY_ITEM_LAYOUT_MASK)
  let bbox = w.node.computeBounds()
  if bbox.w > 0 or bbox.h > 0:
    let width = if (w.layBehave and LAY_HFILL) != LAY_HFILL: bbox.w else: 0
    let height = if (w.layBehave and LAY_VFILL) != LAY_VFILL: bbox.h else: 0
    if width > 0 or height > 0: lay_set_size_xy(gui.layoutCtx, id, width, height)
  return id

proc setLayoutBounds*(w: Widget, dest: Rect) =
  if dest.w <= 0 or dest.h <= 0: return
  let src = w.node.computeBounds()
  if w.onApplyLayout != nil and w.onApplyLayout(src, dest): return
  let sx = if abs(dest.w - src.w) < 1e-3: 1.0f else: dest.w / src.w
  let sy = if abs(dest.h - src.h) < 1e-3: 1.0f else: dest.h / src.h
  let dx = dest.x - src.x
  let dy = dest.y - src.y
  if sx == 1.0 and sy == 1.0 and abs(dx) < 1e-3 and abs(dy) < 1e-3: return
  w.layoutTransform = translationMat3(vec2(dx, dy)) * w.layoutTransform * scaleMat3(vec2(sx, sy))

proc applyLayout*(gui: SvgGui, w: Widget) =
  if w.layoutId == LAY_INVALID_ID: return
  let r = lay_get_rect(gui.layoutCtx, w.layoutId)
  let dest = rect(r[0], r[1], r[2], r[3])
  if (w.layContain and LAYX_HASLAYOUT) != 0:
    for childNode in w.node.children:
      if not childNode.visible or childNode.attrs.getOrDefault("position", "") == "absolute": continue
      if gui.nodeToWidget.hasKey(childNode): gui.applyLayout(gui.nodeToWidget[childNode])
  w.setLayoutBounds(dest)

proc layoutWindow*(gui: SvgGui, win: Window, bbox: Rect) =
  lay_reset_context(gui.layoutCtx)
  let rootId = lay_item(gui.layoutCtx)
  lay_set_size_xy(gui.layoutCtx, rootId, bbox.w, bbox.h)
  let docId = gui.prepareLayout(win)
  lay_insert(gui.layoutCtx, rootId, docId)
  lay_run_context(gui.layoutCtx)
  gui.applyLayout(win)
  lay_reset_context(gui.layoutCtx)

proc isDescendant*(child, parent: Widget): bool =
  if child == nil or parent == nil: return false
  var curr = child.node
  while curr != nil:
    if curr == parent.node: return true
    curr = curr.parent
  return false

proc commonParent*(gui: SvgGui, wa, wb: Widget): Widget =
  if wa == nil or wb == nil: return nil
  var pathA = newSeq[Node]()
  var a = wa.node
  while a != nil: pathA.add(a); a = a.parent
  var b = wb.node
  while b != nil:
    for node in pathA:
      if node == b: return gui.getWidget(node)
    b = b.parent
  return nil

proc widgetAt*(gui: SvgGui, win: Window, p: Vec2): Widget =
  proc findAt(node: Node, p: Vec2): Node =
    if not node.visible: return nil
    for i in countdown(node.children.len - 1, 0):
      let child = node.children[i]
      let hit = findAt(child, p)
      if hit != nil: return hit
    if node.computeBounds().contains(p): return node
    return nil
  let hitNode = findAt(win.node, p)
  if hitNode != nil: return gui.getWidget(hitNode)
  return nil

proc setVisible*(w: Widget, visible: bool) = w.node.visible = visible

proc rootWindow*(win: Window): Window =
  var curr = win
  while curr.parentWindow != nil: curr = curr.parentWindow
  return curr

proc showWindow*(gui: SvgGui, win: Window, parent: Window = nil, showModal = false) =
  win.parentWindow = parent
  gui.windows.add(win)
  if parent != nil and showModal:
    win.isModal = true
    parent.rootWindow().currentModal = win
  win.setVisible(true)
  if win.windyWindow == nil:
    win.windyWindow = newWindow(win.winTitle, ivec2(win.winBounds.w.int32, win.winBounds.h.int32))

proc closeWindow*(gui: SvgGui, win: Window) =
  win.setVisible(false)
  let idx = gui.windows.find(win)
  if idx != -1: gui.windows.delete(idx)
  if win.isModal and win.parentWindow != nil:
    win.parentWindow.rootWindow().currentModal = nil
  if win.windyWindow != nil: win.windyWindow.close()

proc hoveredLeave*(gui: SvgGui, widget: Widget, topWidget: Widget = nil, event: Event = nil) =
  if gui.hoveredWidget == nil or widget == gui.hoveredWidget: return
  var leaving = gui.hoveredWidget
  while leaving != nil and leaving != widget:
    # Dispatch LEAVE event
    let ev = Event(kind: MouseMove) # Simplified
    for h in leaving.handlers: discard h(gui, ev)
    if leaving == topWidget: break
    var parentNode = leaving.node.parent
    leaving = if parentNode != nil: gui.getWidget(parentNode) else: nil
  gui.hoveredWidget = widget

proc sendEvent*(gui: SvgGui, win: Window, widget: Widget, event: Event): bool =
  var target = widget
  if target == nil: target = if gui.menuStack.len > 0: gui.menuStack[^1] else: win
  if event.kind == MouseMove:
    let modalWidget = if gui.menuStack.len > 0: gui.menuStack[^1] else: win.currentModal
    let topWidget = if gui.pressedWidget != nil: gui.pressedWidget else: modalWidget
    if target != gui.hoveredWidget:
      let common = gui.commonParent(target, gui.hoveredWidget)
      gui.hoveredLeave(common, topWidget, event)
      var entering = if gui.pressedWidget != nil: gui.pressedWidget else: target
      while entering != nil and entering != common:
        let ev = Event(kind: MouseMove) # Simplified ENTER
        for h in entering.handlers: discard h(gui, ev)
        if entering == topWidget: break
        var parentNode = entering.node.parent
        entering = if parentNode != nil: gui.getWidget(parentNode) else: nil
      gui.hoveredWidget = target
  if gui.pressedWidget != nil:
    if target != nil and target.isDescendant(gui.pressedWidget):
      for h in gui.pressedWidget.handlers:
        if h(gui, event):
          if event.kind == ButtonUp: gui.pressedWidget = nil
          return true
    elif event.kind == ButtonUp:
      gui.pressedWidget = nil
      return true
  var curr = target
  while curr != nil:
    for handler in curr.handlers:
      if handler(gui, event): return true
    var parentNode = curr.node.parent
    curr = if parentNode != nil: gui.getWidget(parentNode) else: nil
  return false

proc updateGestures*(gui: SvgGui, event: Event) =
  let p = event.pos.vec2
  let t = epochTime()
  if event.kind == ButtonDown:
    gui.flingV = vec2(0, 0)
    gui.fingerClicks = if (t - gui.fingerUpDnTime < 0.4) and (p.dist(gui.prevFingerPos) < 32): gui.fingerClicks + 1 else: 1
    gui.totalFingerDist = 0
    gui.fingerUpDnTime = t
    gui.pressEvent = event
  elif event.kind == MouseMove:
    gui.totalFingerDist += p.dist(gui.prevFingerPos)
    if gui.totalFingerDist >= 20 or (t - gui.fingerUpDnTime >= 0.4): gui.fingerClicks = 0
  elif event.kind == ButtonUp:
    if gui.totalFingerDist >= 20 or (t - gui.fingerUpDnTime >= 0.4): gui.fingerClicks = 0
    gui.fingerUpDnTime = t
  gui.prevFingerPos = p

proc newSvgGui*(): SvgGui =
  new(result)
  init_lay_context(result.layoutCtx)
  result.nodeToWidget = initTable[Node, Widget]()

proc showMenu*(gui: SvgGui, menu: Widget) =
  menu.setVisible(true)
  gui.menuStack.add(menu)

proc newWindow*(gui: SvgGui, doc: Node): Window =
  new(result)
  result.gui = gui
  result.node = doc
  result.layoutId = LAY_INVALID_ID
  result.layoutTransform = mat3()
  result.enabled = true
  result.absPosNodes = @[]
  result.handlers = @[]
