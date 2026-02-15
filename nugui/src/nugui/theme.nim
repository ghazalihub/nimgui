import tables, pixie, core, strutils, sets

const defaultThemeSVG* = """
<svg xmlns="http://www.w3.org/2000/svg">
  <defs>
    <svg id="chevron-left" width="96" height="96" viewBox="0 0 96 96">
      <polygon points="57.879,18.277 32.223,47.998 57.879,77.723 63.776,72.634 42.512,47.998 63.776,23.372"/>
    </svg>
    <svg id="chevron-down" width="96" height="96" viewBox="0 0 96 96">
      <polygon points="72.628,32.223 48.002,53.488 23.366,32.223 18.278,38.121 48.002,63.777 77.722,38.121"/>
    </svg>
    <svg id="chevron-right" width="96" height="96" viewBox="0 0 96 96">
      <polygon points="32.223,23.372 53.488,47.998 32.223,72.634 38.121,77.723 63.777,47.998 38.121,18.277"/>
    </svg>
  </defs>

  <g id="menu" class="menu" display="none">
    <rect class="background menu-bg" box-anchor="fill" width="20" height="20"/>
    <g class="child-container" box-anchor="fill" layout="flex" flex-direction="column"></g>
  </g>

  <g id="pushbutton" class="pushbutton" layout="box">
    <rect class="background pushbtn-bg" box-anchor="fill" width="36" height="36" rx="4"/>
    <text class="title" margin="8 8">Button</text>
  </g>

  <g id="checkbox" class="checkbox" layout="box">
    <rect class="background" width="26" height="26" fill="none"/>
    <rect class="box" x="4" y="4" width="18" height="18" fill="none" stroke="currentColor" stroke-width="1.5"/>
    <g class="checkmark" visibility="hidden">
      <rect x="3.25" y="3.25" width="19.5" height="19.5" fill="currentColor"/>
      <path d="M7 13 L11 17 L19 9" stroke="white" stroke-width="2" fill="none"/>
    </g>
  </g>

  <g id="slider" class="slider" box-anchor="hfill" layout="box">
    <rect class="track" box-anchor="hfill" width="200" height="4" y="11" fill="#505050"/>
    <g class="handle-container" box-anchor="left">
        <rect class="handle" width="20" height="26" fill="#CDCDCD" rx="2"/>
    </g>
  </g>

  <g id="progressbar" class="progressbar" box-anchor="hfill" layout="box">
    <rect class="background" box-anchor="fill" width="200" height="12" fill="#202020"/>
    <rect class="fill" box-anchor="left vfill" width="0" height="12" fill="#32809C"/>
  </g>

  <g id="textbox" class="textbox" box-anchor="fill" layout="box">
    <rect class="background" box-anchor="fill" width="150" height="36" fill="#202020" stroke="#555555" stroke-width="1"/>
    <text class="content" box-anchor="left" margin="4 8"></text>
  </g>
</svg>
"""

type
  StyleRule* = object
    selector*: string
    props*: Table[string, string]

var currentThemeSVG*: SvgDocument
var styleRules*: seq[StyleRule] = @[]

proc initDefaultTheme*() =
  currentThemeSVG = parseSvg(defaultThemeSVG)
  # Basic rules
  styleRules.add StyleRule(selector: ".pushbutton", props: {"fill": "#555555"}.toTable)
  styleRules.add StyleRule(selector: ".pushbutton.hovered", props: {"fill": "#4290AC"}.toTable)
  styleRules.add StyleRule(selector: ".pushbutton.pressed", props: {"fill": "#32809C"}.toTable)
  styleRules.add StyleRule(selector: ".checkbox .box", props: {"stroke": "#CDCDCD"}.toTable)
  styleRules.add StyleRule(selector: ".checkbox.checked .checkmark", props: {"visibility": "visible"}.toTable)

proc findNodeById*(root: SvgNode, id: string): SvgNode =
  if root.metadata.getOrDefault("id", "") == id: return root
  if root of SvgGroup:
    for child in SvgGroup(root).children:
      let found = findNodeById(child, id)
      if found != nil: return found
  return nil

proc deepClone*(n: SvgNode): SvgNode =
  # Porting basic deep clone for pixie nodes
  if n of SvgRect:
    let r = SvgRect(n)
    let res = newSvgRect()
    res.x = r.x; res.y = r.y; res.width = r.width; res.height = r.height
    res.rx = r.rx; res.ry = r.ry; res.metadata = r.metadata
    return res
  elif n of SvgText:
    let t = SvgText(n)
    let res = newSvgText()
    res.text = t.text; res.metadata = t.metadata
    return res
  elif n of SvgGroup:
    let g = SvgGroup(n)
    let res = newSvgGroup()
    res.metadata = g.metadata
    for child in g.children:
      res.children.add(deepClone(child))
    return res
  elif n of SvgPath:
    let p = SvgPath(n)
    let res = newSvgPath()
    res.d = p.d; res.metadata = p.metadata
    return res
  return newSvgGroup()

proc createWidgetFromTemplate*(id: string): Widget =
  if currentThemeSVG == nil: initDefaultTheme()
  let tpl = findNodeById(currentThemeSVG, id)
  if tpl == nil:
    return newWidget(newSvgGroup())
  let node = deepClone(tpl)
  result = newWidget(node)
  # Extract initial classes from template
  let cls = tpl.metadata.getOrDefault("class", "")
  if cls != "":
    for c in cls.splitWhitespace():
      result.classes.incl(c)

proc applyStyles*(w: Widget) =
  # Simple rule matcher: .class or .class.state
  for rule in styleRules:
    let parts = rule.selector.split('.')
    if parts.len < 2: continue

    var matches = true
    for i in 1 ..< parts.len:
      if parts[i] not in w.classes:
        matches = false
        break

    if matches:
      for k, v in rule.props:
        w.attributes[k] = v
