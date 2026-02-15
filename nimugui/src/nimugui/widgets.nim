import pixie, windy, vmath, chroma, std/[options, tables, sequtils, algorithm, times, strutils, math]
import svggui, selectors

type
  Button* = ref object of Widget
    onPressed*: proc()
    onClicked*: proc()
    menu*: Menu
    checked*: bool

  Menu* = ref object of Widget
    autoClose*: bool
    align*: int

  TextBox* = ref object of Widget
    textNode*: TextNode

  ComboBox* = ref object of Widget
    items*: seq[string]
    currIndex*: int
    onChanged*: proc(text: string)
    comboMenu*: Menu
    comboText*: TextBox

  SpinBox* = ref object of Widget
    value*: float32
    step*: float32
    minVal*, maxVal*: float32
    onValueChanged*: proc(val: float32)
    spinboxText*: TextBox

  Slider* = ref object of Widget
    sliderPos*: float32
    onValueChanged*: proc(val: float32)
    sliderHandle*: Button

  Splitter* = ref object of Widget
    minSize*: float32
    currSize*: float32
    onSplitChanged*: proc(val: float32)

  ScrollWidget* = ref object of Widget
    contents*: Widget
    scrollX*, scrollY*: float32
    onScroll*: proc()

  Dialog* = ref object of Window
    onFinished*: proc(result: int)
    result*: int

const
  MENU_VERT* = 1
  MENU_HORZ* = 2
  MENU_LEFT* = 4
  MENU_RIGHT* = 8
  MENU_ABOVE* = 16

proc selectFirst*(w: Widget, selector: string): Widget =
  let res = selectFirst(w.node, selector)
  if res != nil: return w.gui.getWidget(res)
  return nil

proc newButton*(gui: SvgGui, node: Node): Button =
  new(result)
  result.gui = gui
  result.node = node
  result.enabled = true
  result.handlers = @[]
  let btn = result
  result.handlers.add(proc(gui: SvgGui, event: Event): bool =
    if event.kind == ButtonDown:
      if btn.menu != nil: gui.showMenu(btn.menu)
      gui.pressedWidget = btn
      if btn.onPressed != nil: btn.onPressed()
      return true
    elif event.kind == ButtonUp:
      if btn.onClicked != nil: btn.onClicked()
      return true
    return false
  )

proc newMenu*(gui: SvgGui, node: Node): Menu =
  new(result)
  result.gui = gui
  result.node = node
  result.isPressedGroupContainer = true
  result.setVisible(false)
  result.handlers = @[]
  result.handlers.add(proc(gui: SvgGui, event: Event): bool =
    return false
  )

proc addItem*(m: Menu, item: Widget) =
  m.node.children.add(item.node)
  item.node.parent = m.node
  discard m.gui.getWidget(item.node)

proc newTextBox*(gui: SvgGui, node: Node): TextBox =
  new(result)
  result.gui = gui
  result.node = node
  if node of TextNode: result.textNode = TextNode(node)
  else:
    for child in node.children:
      if child of TextNode: result.textNode = TextNode(child); break

proc setText*(tb: TextBox, text: string) =
  if tb.textNode != nil: tb.textNode.text = text

proc newComboBox*(gui: SvgGui, node: Node, items: seq[string] = @[]): ComboBox =
  new(result)
  result.gui = gui
  result.node = node
  result.items = items
  let mNode = node.selectFirst(".combo_menu")
  if mNode != nil: result.comboMenu = newMenu(gui, mNode)
  let tNode = node.selectFirst(".combo_text")
  if tNode != nil: result.comboText = newTextBox(gui, tNode)

proc newSpinBox*(gui: SvgGui, node: Node, val: float32 = 0, inc: float32 = 1): SpinBox =
  new(result)
  result.gui = gui
  result.node = node
  result.value = val
  result.step = inc
  let tNode = node.selectFirst(".spinbox_text")
  if tNode != nil: result.spinboxText = newTextBox(gui, tNode)

proc newSlider*(gui: SvgGui, node: Node): Slider =
  new(result)
  result.gui = gui
  result.node = node
  let hNode = node.selectFirst(".slider-handle")
  if hNode != nil: result.sliderHandle = newButton(gui, hNode)

proc newSplitter*(gui: SvgGui, node: Node): Splitter =
  new(result)
  result.gui = gui
  result.node = node

proc newScrollWidget*(gui: SvgGui, doc: Node, contents: Widget): ScrollWidget =
  new(result)
  result.gui = gui
  result.node = doc
  result.contents = contents

proc newDialog*(gui: SvgGui, doc: Node): Dialog =
  new(result)
  result.gui = gui
  result.node = doc
  result.absPosNodes = @[]
  result.handlers = @[]
