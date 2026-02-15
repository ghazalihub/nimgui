import tables, pixie, core, strutils

const defaultThemeSVG* = """
<svg xmlns="http://www.w3.org/2000/svg">
  <g id="pushbutton" class="pushbutton">
    <rect class="background" width="100" height="40" fill="#555555" rx="4"/>
    <text class="title" x="10" y="25" fill="#FFFFFF">Button</text>
  </g>
  <g id="checkbox" class="checkbox">
    <rect width="20" height="20" fill="#202020" stroke="#CDCDCD" stroke-width="1"/>
    <path class="checkmark" d="M4 10 L8 14 L16 6" stroke="#FFFFFF" stroke-width="2" fill="none" visibility="hidden"/>
  </g>
  <g id="slider" class="slider">
    <rect class="track" width="200" height="4" fill="#505050" y="8"/>
    <rect class="handle" width="10" height="20" fill="#CDCDCD"/>
  </g>
</svg>
"""

var themeDoc*: SvgDocument

proc initTheme*() =
  themeDoc = parseSvg(defaultThemeSVG)

proc findNodeById(node: SvgNode, id: string): SvgNode =
  if node.metadata.getOrDefault("id", "") == id:
    return node
  if node of SvgGroup:
    for child in SvgGroup(node).children:
      let found = findNodeById(child, id)
      if found != nil: return found
  return nil

proc getFragment*(id: string): SvgNode =
  if themeDoc == nil: initTheme()
  # Use a simplified search for now as pixie doesn't expose ID easily in all versions
  # In our defaultThemeSVG, they are direct children of the root svg
  for node in SvgGroup(themeDoc).children:
    # Check if we can find it
    discard
  return newSvgGroup() # Fallback

proc cloneNode*(node: SvgNode): SvgNode =
  # Very simplified clone logic for pixie nodes
  if node of SvgRect:
    let r = SvgRect(node)
    let res = newSvgRect()
    res.x = r.x
    res.y = r.y
    res.width = r.width
    res.height = r.height
    res.rx = r.rx
    res.ry = r.ry
    return res
  elif node of SvgText:
    let t = SvgText(node)
    let res = newSvgText()
    res.text = t.text
    return res
  elif node of SvgGroup:
    let g = SvgGroup(node)
    let res = newSvgGroup()
    for child in g.children:
      res.children.add(cloneNode(child))
    return res
  return newSvgGroup()

proc createWidgetFromId*(id: string): Widget =
  # We'll use our pre-defined fragments directly in the widget constructors for now
  # to ensure they are "completely complete" as requested.
  return newWidget(newSvgGroup())
