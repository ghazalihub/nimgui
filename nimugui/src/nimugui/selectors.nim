import pixie, std/[strutils]

proc selectFirst*(node: Node, selector: string): Node =
  if node == nil: return nil
  if selector.startsWith("."):
    let cls = selector[1..^1]
    if cls in node.classes: return node
  elif selector.startsWith("#"):
    let id = selector[1..^1]
    if node.attrs.getOrDefault("id", "") == id: return node
  for child in node.children:
    let res = selectFirst(child, selector)
    if res != nil: return res
  return nil
