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

  <g id="pushbutton" class="pushbutton" layout="box">
    <rect class="background" box-anchor="fill" width="36" height="36" rx="4"/>
    <text class="title" margin="8 8">Button</text>
  </g>
</svg>
"""

type
  StyleRule* = object
    selector*: seq[string]
    props*: Table[string, string]

var styleRules*: seq[StyleRule] = @[]
var themeVars*: Table[string, string] = initTable[string, string]()

proc initDefaultTheme*() =
  themeVars["--button"] = "#555555"
  themeVars["--hovered"] = "#4290AC"
  themeVars["--pressed"] = "#32809C"
  styleRules.add StyleRule(selector: @[".pushbutton"], props: {"fill": "var(--button)"}.toTable)
  styleRules.add StyleRule(selector: @[".pushbutton.hovered"], props: {"fill": "var(--hovered)"}.toTable)
  styleRules.add StyleRule(selector: @[".pushbutton.pressed"], props: {"fill": "var(--pressed)"}.toTable)

proc resolveVar(val: string): string =
  if val.startsWith("var("):
    let v = val[4..^2]
    return themeVars.getOrDefault(v, val)
  return val

proc matchesSelector(w: Widget, selectorPart: string): bool =
  let classes = selectorPart.split('.')
  for c in classes:
    if c == "": continue
    if c not in w.classes: return false
  return true

proc applyStylesRec(w: Widget, ancestors: var seq[Widget]) =
  for rule in styleRules:
    if rule.selector.len == 0: continue
    if matchesSelector(w, rule.selector[^1]):
      var match = true
      if rule.selector.len > 1:
        var ai = ancestors.len - 1
        for i in countdown(rule.selector.len - 2, 0):
          let target = rule.selector[i]
          var found = false
          while ai >= 0:
            if matchesSelector(ancestors[ai], target):
              found = true; ai -= 1; break
            ai -= 1
          if not found: match = false; break
      if match:
        for k, v in rule.props: w.attributes[k] = resolveVar(v)
  ancestors.add w
  for child in w.children: applyStylesRec(child, ancestors)
  discard ancestors.pop()

proc applyStyles*(root: Widget) =
  var ancestors: seq[Widget] = @[]
  applyStylesRec(root, ancestors)

proc parseColor*(s: string): chroma.Color =
  if s.startsWith("#"):
    let hex = s.strip(chars = {'#'})
    if hex.len == 6:
      let r = fromHex[uint8](hex[0..1])
      let g = fromHex[uint8](hex[2..3])
      let b = fromHex[uint8](hex[4..5])
      return chroma.rgba(r, g, b, 255).color
  return chroma.rgba(200, 200, 200, 255).color
