import pixie, windy, vmath, chroma, std/[tables]
import ../src/nimugui/[svggui, widgets, layout, theme, selectors]

proc main() =
  let gui = newSvgGui()

  # Load theme
  let themeNode = parseSvg(defaultWidgetSVG)

  # Create a window
  let windowNode = parseSvg("""<svg width="800" height="600" layout="flex" flex-direction="column"></svg>""")
  let win = newWindow(gui, windowNode)
  win.winTitle = "NimUGUI Demo"
  win.winBounds = rect(0, 0, 800, 600)

  # Create a button from theme
  let btnNodeBase = themeNode.selectFirst("#button")
  if btnNodeBase != nil:
    let btnNode = btnNodeBase.clone()
    let btn = newButton(gui, btnNode)
    btn.onClicked = proc() =
      echo "Button Clicked!"

    win.node.children.add(btn.node)
    btn.node.parent = win.node

  gui.showWindow(win)

  # Layout
  gui.layoutWindow(win, win.winBounds)

  echo "NimUGUI Demo Started"

if isMainModule:
  main()
