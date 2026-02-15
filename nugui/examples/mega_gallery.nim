import nugui/core, nugui/widgets, nugui/textedit, nugui/dsl, nugui/renderer, windy, pixie, vmath

proc main() =
  let gui = newSvgGui()

  # Building the UI declaratively
  let win = uiWindow "Nugui Mega Gallery":
    uiNavbar:
      uiRow:
        uiLabel "NUGUI v1.0"
        uiButton "Home"
        uiButton "GitHub"

    uiRow:
      uiSidebar:
        uiColumn:
          uiButton "Dashboard"
          uiButton "Settings"

      uiColumn:
        uiCard:
          uiColumn:
            uiLabel "Inputs"
            uiTextEdit "Edit me"
            uiCheckbox "Active", true
            uiSlider 0.5

        uiCard:
          uiColumn:
            uiLabel "Data"
            uiListView @["Item 1", "Item 2", "Item 3"]
            uiRating 4

  # windy setup
  let w = newWindow("Nugui Gallery", ivec2(1024, 768))
  win.windyWindow = w
  win.winBounds = rect(0, 0, 1024, 768)
  gui.windows.add(win)

  while not w.closeRequested:
    gui.updateAndDraw()
    w.swapBuffers()
    pollEvents()

if isMainModule:
  main()
