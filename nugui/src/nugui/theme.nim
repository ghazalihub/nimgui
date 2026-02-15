import tables, pixie, core

type
  Theme* = ref object
    colors*: Table[string, Color]
    svgFragments*: Table[string, string]

proc newDefaultTheme*(): Theme =
  new(result)
  result.colors = initTable[string, Color]()
  result.colors["dark"] = parseHtmlColor("#101010")
  result.colors["window"] = parseHtmlColor("#303030")
  result.colors["light"] = parseHtmlColor("#505050")
  result.colors["base"] = parseHtmlColor("#202020")
  result.colors["button"] = parseHtmlColor("#555555")
  result.colors["hovered"] = parseHtmlColor("#32809C")
  result.colors["pressed"] = parseHtmlColor("#32809C")
  result.colors["checked"] = parseHtmlColor("#0000C0")
  result.colors["title"] = parseHtmlColor("#2EA3CF")
  result.colors["text"] = parseHtmlColor("#F2F2F2")

  result.svgFragments = initTable[string, string]()
  result.svgFragments["button"] = """
    <g class="pushbutton" box-anchor="fill" layout="box">
      <rect class="background pushbtn-bg" box-anchor="hfill" width="36" height="36"/>
      <text class="title" margin="8 8"></text>
    </g>
  """
  # ... more fragments

var currentTheme*: Theme = newDefaultTheme()

proc applyStyle*(w: Widget) =
  # Logic to apply theme based on widget class
  discard
