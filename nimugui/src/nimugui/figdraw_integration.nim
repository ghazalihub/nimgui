import pixie, vmath, chroma, std/[tables]
import svggui

# Mocking FigDraw types as I can't install the package
type
  ZLevel* = int
  FigKind* = enum nkRectangle, nkText, nkGroup
  RenderStroke* = object
    weight*: float32
    color*: Color
  Fig* = object
    kind*: FigKind
    screenBox*: Rect
    fill*: Color
    corners*: array[4, float32]
    stroke*: RenderStroke
    text*: string
  RenderList* = ref object
  Renders* = object
    layers*: OrderedTable[ZLevel, RenderList]

proc addRoot*(list: RenderList, fig: Fig): int = 0
proc addChild*(list: RenderList, parentIdx: int, fig: Fig): int = 0

proc toFig*(node: Node, offset: Vec2, list: RenderList, parentIdx: int): int =
  var fig: Fig
  if node of RectNode:
    let rn = RectNode(node)
    fig = Fig(
      kind: nkRectangle,
      screenBox: rect(rn.pos.x + offset.x, rn.pos.y + offset.y, rn.wh.x, rn.wh.y),
      # fill: rn.fill.color # SolidFill color
    )
  elif node of TextNode:
    let tn = TextNode(node)
    fig = Fig(
      kind: nkText,
      screenBox: rect(tn.pos.x + offset.x, tn.pos.y + offset.y, 100, 20),
      text: tn.text
    )
  else:
    fig = Fig(kind: nkGroup)

  let idx = if parentIdx == -1: list.addRoot(fig) else: list.addChild(parentIdx, fig)
  for child in node.children:
    discard toFig(child, offset + node.pos, list, idx)
  return idx

proc render*(gui: SvgGui, win: Window): Renders =
  var list = RenderList()
  discard toFig(win.node, vec2(0, 0), list, -1)
  result = Renders(layers: initOrderedTable[ZLevel, RenderList]())
  result.layers[0.ZLevel] = list
