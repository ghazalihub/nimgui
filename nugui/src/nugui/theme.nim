import tables, pixie, core, strutils, sets, vmath

const defaultThemeSVG* = """
<svg xmlns="http://www.w3.org/2000/svg">
  <defs>
    <g id="icon-chevron-down"><path d="M7 10l5 5 5-5H7z"/></g>
    <g id="icon-chevron-right"><path d="M10 17l5-5-5-5v10z"/></g>
    <g id="icon-chevron-left"><path d="M14 7l-5 5 5 5V7z"/></g>
    <g id="icon-check"><path d="M9 16.17L4.83 12l-1.42 1.41L9 19 21 7l-1.41-1.41z"/></g>
    <g id="icon-close"><path d="M19 6.41L17.59 5 12 10.59 6.41 5 5 6.41 10.59 12 5 17.59 6.41 19 12 13.41 17.59 19 19 17.59 13.41 12z"/></g>
    <g id="icon-search"><path d="M15.5 14h-.79l-.28-.27A6.471 6.471 0 0 0 16 9.5 6.5 6.5 0 1 0 9.5 16c1.61 0 3.09-.59 4.23-1.57l.27.28v.79l5 4.99L20.49 19l-4.99-5zm-6 0C7.01 14 5 11.99 5 9.5S7.01 5 9.5 5 14 7.01 14 9.5 11.99 14 9.5 14z"/></g>
    <g id="icon-star"><path d="M12 17.27L18.18 21l-1.64-7.03L22 9.24l-7.19-.61L12 2 9.19 8.63 2 9.24l5.46 4.73L5.82 21z"/></g>
  </defs>

  <g id="pushbutton" class="pushbutton" layout="box">
    <rect class="background" box-anchor="fill" width="100" height="36" rx="4" fill="var(--button)"/>
    <text class="title" margin="0 12" box-anchor="center" fill="var(--text)">Button</text>
  </g>

  <g id="checkbox" class="checkbox" layout="box">
    <rect class="box" width="20" height="20" rx="2" fill="var(--base)" stroke="var(--light)" stroke-width="1"/>
    <use class="checkmark" xlink:href="#icon-check" fill="var(--title)" visibility="hidden"/>
    <text class="label" margin="0 8" fill="var(--text)">Checkbox</text>
  </g>

  <g id="radio" class="radio" layout="box">
    <circle class="outer" cx="10" cy="10" r="9" fill="var(--base)" stroke="var(--light)" stroke-width="1"/>
    <circle class="inner" cx="10" cy="10" r="5" fill="var(--title)" visibility="hidden"/>
    <text class="label" margin="0 8" fill="var(--text)">Radio</text>
  </g>

  <g id="slider" class="slider" layout="box" box-anchor="hfill">
    <rect class="track" box-anchor="hfill" y="16" width="200" height="4" rx="2" fill="var(--light)"/>
    <g class="handle-container" box-anchor="left">
      <circle class="handle" cx="0" cy="18" r="10" fill="var(--text)" stroke="var(--title)" stroke-width="2"/>
    </g>
  </g>

  <g id="textbox" class="textbox" layout="box" box-anchor="hfill">
    <rect class="background" box-anchor="fill" width="150" height="36" rx="4" fill="var(--base)" stroke="var(--light)" stroke-width="1"/>
    <text class="content" box-anchor="left" margin="0 8" fill="var(--text)"></text>
  </g>

  <g id="combobox" class="combobox" layout="box" box-anchor="hfill">
    <rect class="background" box-anchor="fill" width="150" height="36" rx="4" fill="var(--base)" stroke="var(--light)" stroke-width="1"/>
    <text class="current-text" box-anchor="left" margin="0 8" fill="var(--text)">Select...</text>
    <use xlink:href="#icon-chevron-down" box-anchor="right" margin="0 8" fill="var(--icon)"/>
  </g>

  <g id="card" class="card" layout="flex" flex-direction="column">
    <rect class="background" box-anchor="fill" rx="8" fill="var(--window)"/>
    <g class="header" margin="12 16" layout="box"></g>
    <g class="body" margin="0 16 16 16" layout="flex" flex-direction="column"></g>
  </g>

  <g id="datagrid" class="datagrid" layout="flex" flex-direction="column">
    <g class="header-row" layout="flex" flex-direction="row" height="32" fill="var(--dark)"></g>
    <g class="rows" layout="flex" flex-direction="column"></g>
  </g>

  <g id="carousel" class="carousel" layout="box">
    <rect class="bg" box-anchor="fill" fill="var(--base)"/>
    <g class="items" layout="flex" flex-direction="row"></g>
    <use xlink:href="#icon-chevron-left" box-anchor="left" margin="0 8" fill="white"/>
    <use xlink:href="#icon-chevron-right" box-anchor="right" margin="0 8" fill="white"/>
  </g>

  <g id="datepicker" class="datepicker" layout="flex" flex-direction="column" width="250">
    <rect class="bg" box-anchor="fill" rx="4" fill="var(--window)" stroke="var(--light)"/>
    <g class="header" layout="box" height="40">
        <use xlink:href="#icon-chevron-left" box-anchor="left" margin="0 8" fill="var(--icon)"/>
        <text class="month-year" box-anchor="center" fill="var(--text)">October 2023</text>
        <use xlink:href="#icon-chevron-right" box-anchor="right" margin="0 8" fill="var(--icon)"/>
    </g>
    <g class="grid" layout="flex" flex-direction="column" margin="8"></g>
  </g>

  <g id="color-picker" class="color-picker" layout="flex" flex-direction="column" width="200">
    <rect class="sv-box" width="200" height="150" fill="red"/>
    <rect class="hue-slider" margin="8 0" width="200" height="20" fill="var(--light)"/>
  </g>

  <g id="tree-item" class="tree-item" layout="flex" flex-direction="column">
    <g class="header" layout="flex" flex-direction="row" height="32">
        <use xlink:href="#icon-chevron-right" margin="0 4" fill="var(--icon)"/>
        <text class="label" fill="var(--text)">Node</text>
    </g>
  </g>

  <g id="badge" class="badge" layout="box">
    <rect class="bg" box-anchor="fill" rx="10" fill="var(--title)"/>
    <text class="label" margin="2 8" font-size="12" fill="white">0</text>
  </g>

  <g id="avatar" class="avatar">
    <circle cx="20" cy="20" r="20" fill="var(--light)"/>
    <text class="initials" x="20" y="24" text-anchor="middle" fill="white" font-size="16">JD</text>
  </g>

  <g id="progressbar" class="progressbar" layout="box" box-anchor="hfill">
    <rect class="background" box-anchor="fill" width="200" height="12" rx="6" fill="var(--base)"/>
    <rect class="fill" box-anchor="left vfill" width="0" height="12" rx="6" fill="var(--title)"/>
  </g>

  <g id="spinner" class="spinner" width="24" height="24">
    <circle cx="12" cy="12" r="10" fill="none" stroke="var(--light)" stroke-width="3"/>
    <path d="M12 2a10 10 0 0 1 10 10" fill="none" stroke="var(--title)" stroke-width="3"/>
  </g>

  <g id="navbar" class="navbar" layout="box" height="64" box-anchor="hfill">
    <rect class="bg" box-anchor="fill" fill="var(--dark)"/>
    <text class="logo" box-anchor="left" margin="0 24" font-weight="bold" fill="var(--title)">NUGUI</text>
  </g>

  <g id="sidebar" class="sidebar" layout="flex" flex-direction="column" width="240" box-anchor="vfill">
    <rect class="bg" box-anchor="fill" fill="var(--base)"/>
  </g>

  <g id="divider" class="divider" layout="box" box-anchor="hfill" height="1">
    <rect box-anchor="fill" fill="var(--light)"/>
  </g>

  <g id="scrollarea" class="scrollarea" layout="box">
    <g class="viewport" box-anchor="fill" layout="box"></g>
  </g>
</svg>
"""

type
  StyleRule* = object
    selector*: seq[string]
    props*: Table[string, string]

var currentThemeSVG*: SvgDocument
var styleRules*: seq[StyleRule] = @[]
var themeVars*: Table[string, string] = initTable[string, string]()

proc initDefaultTheme*() =
  currentThemeSVG = parseSvg(defaultThemeSVG)
  themeVars["--dark"] = "#101010"; themeVars["--window"] = "#303030"; themeVars["--light"] = "#505050"
  themeVars["--base"] = "#202020"; themeVars["--button"] = "#555555"; themeVars["--hovered"] = "#32809C"
  themeVars["--pressed"] = "#4290AC"; themeVars["--checked"] = "#0000C0"; themeVars["--title"] = "#2EA3CF"
  themeVars["--text"] = "#F2F2F2"; themeVars["--icon"] = "#CDCDCD"

  styleRules.add StyleRule(selector: @[".pushbutton.pressed"], props: {"fill": "var(--pressed)"}.toTable)
  styleRules.add StyleRule(selector: @[".pushbutton.hovered"], props: {"fill": "var(--hovered)"}.toTable)
  styleRules.add StyleRule(selector: @[".checkbox.checked .checkmark"], props: {"visibility": "visible"}.toTable)
  styleRules.add StyleRule(selector: @[".switch.checked .checkmark"], props: {"visibility": "visible"}.toTable)

proc resolveVar(val: string): string =
  if val.startsWith("var("): themeVars.getOrDefault(val[4..^2], val) else: val

proc matchesSelector(w: Widget, selectorPart: string): bool =
  for c in selectorPart.split('.'): (if c != "" and c not in w.classes: return false)
  return true

proc applyStylesRec(w: Widget, ancestors: var seq[Widget]) =
  for rule in styleRules:
    if matchesSelector(w, rule.selector[^1]):
      var match = true
      if rule.selector.len > 1:
        var ai = ancestors.len - 1
        for i in countdown(rule.selector.len - 2, 0):
          var found = false
          while ai >= 0:
            if matchesSelector(ancestors[ai], rule.selector[i]): (found = true; ai -= 1; break)
            ai -= 1
          if not found: (match = false; break)
      if match: (for k, v in rule.props: w.attributes[k] = resolveVar(v))
  ancestors.add w; for child in w.children: applyStylesRec(child, ancestors); discard ancestors.pop()

proc applyStyles*(root: Widget) =
  var ancestors: seq[Widget] = @[]; applyStylesRec(root, ancestors)

proc deepClone*(n: SvgNode): SvgNode =
  if n of SvgRect: (let r = SvgRect(n); let res = newSvgRect(); res.x = r.x; res.y = r.y; res.width = r.width; res.height = r.height; res.rx = r.rx; res.ry = r.ry; res.metadata = r.metadata; return res)
  elif n of SvgText: (let t = SvgText(n); let res = newSvgText(); res.text = t.text; res.metadata = t.metadata; return res)
  elif n of SvgGroup: (let g = SvgGroup(n); let res = newSvgGroup(); res.metadata = g.metadata; for child in g.children: res.children.add(deepClone(child)); return res)
  elif n of SvgUse: (let u = SvgUse(n); let res = newSvgUse(); res.x = u.x; res.y = u.y; res.width = u.width; res.height = u.height; res.href = u.href; res.metadata = u.metadata; return res)
  elif n of SvgCircle: (let c = SvgCircle(n); let res = newSvgCircle(); res.cx = c.cx; res.cy = c.cy; res.r = c.r; res.metadata = c.metadata; return res)
  elif n of SvgPath: (let p = SvgPath(n); let res = newSvgPath(); res.d = p.d; res.metadata = p.metadata; return res)
  return newSvgGroup()

proc findNodeById*(root: SvgNode, id: string): SvgNode =
  if root.metadata.getOrDefault("id", "") == id: return root
  if root of SvgGroup: (for child in SvgGroup(root).children: (let found = findNodeById(child, id); if found != nil: return found))
  return nil

proc createWidgetFromTemplate*(id: string): Widget =
  if currentThemeSVG == nil: initDefaultTheme()
  let tpl = findNodeById(currentThemeSVG, id)
  if tpl == nil: return newWidget()
  result = newWidget(deepClone(tpl))
  for c in tpl.metadata.getOrDefault("class", "").splitWhitespace(): result.classes.incl(c)

proc parseColor*(s: string): chroma.Color =
  if s.startsWith("#"): (let hex = s.strip(chars = {'#'}); if hex.len == 6: return chroma.rgba(fromHex[uint8](hex[0..1]), fromHex[uint8](hex[2..3]), fromHex[uint8](hex[4..5]), 255).color)
  return chroma.rgba(0,0,0,0).color
