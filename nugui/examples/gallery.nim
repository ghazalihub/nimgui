import nugui/core, nugui/widgets, nugui/textedit, nugui/dsl, nugui/renderer, windy, pixie, vmath

proc main() =
  let gui = newSvgGui()

  let win = uiWindow "Widget Gallery":
    uiColumn:
      uiRow:
        uiButton "Click Me"
      uiRow:
        uiLabel "Status: Ready"

  # Set up windy window
  let w = newWindow("Nugui Gallery", ivec2(800, 600))
  win.windyWindow = w
  gui.windows.add(win)

  while not w.closeRequested:
    gui.processEvents()
    gui.draw()
    # Rendering to screen would happen here via figdraw
    w.swapBuffers()
    pollEvents()

  echo "Gallery closed."

if isMainModule:
  main()
