import pixie, vmath
import svggui

type
  ProgressBar* = ref object of Widget
    value*: float32 # 0 to 1

  Tab* = object
    title*: string
    content*: Widget

  Tabs* = ref object of Widget
    tabs*: seq[Tab]
    activeTab*: int

  ListView* = ref object of Widget
    items*: seq[string]
    onItemClicked*: proc(index: int)

proc newProgressBar*(gui: SvgGui, node: Node): ProgressBar =
  new(result)
  result.gui = gui
  result.node = node
  result.value = 0

proc newTabs*(gui: SvgGui, node: Node): Tabs =
  new(result)
  result.gui = gui
  result.node = node
  result.tabs = @[]
  result.activeTab = -1

proc newListView*(gui: SvgGui, node: Node): ListView =
  new(result)
  result.gui = gui
  result.node = node
  result.items = @[]

proc update*(pb: ProgressBar, val: float32) =
  pb.value = clamp(val, 0.0, 1.0)
  # Update SVG visual
  discard
