import nugui/core, nugui/widgets, nugui/textedit, nugui/dsl, nugui/renderer, nugui/theme, windy, pixie, vmath

proc main() =
  let gui = newSvgGui()
  initDefaultTheme()

  # Building a complex UI declaratively
  let win = uiWindow "Nugui Mega Gallery":
    uiNavbar:
      uiRow:
        uiLabel "NUGUI PLATFORM"
        uiButton "Home"
        uiButton "Docs"

    uiRow:
      uiSidebar:
        uiColumn:
          uiButton "Inbox"
          uiButton "Sent"
          uiButton "Archive"

      uiColumn:
        uiCard:
          uiColumn:
            uiLabel "User Profile"
            uiRow:
              uiLabel "Name:"
              uiTextEdit "Jules"
            uiCheckbox "Public Profile", true
            uiRow:
              uiButton "Save", proc() = echo "Saved!"

        uiCard:
          uiColumn:
            uiLabel "System Stats"
            uiProgressBar 0.8
            uiSlider 0.5
            uiTabs @["CPU", "Disk"]
            uiDataGrid(@["Metric", "Value"], @[@["Up", "24d"], @["Users", "1.2k"]])

  # Windy window setup
  let w = newWindow("Mega Gallery", ivec2(1024, 768))
  win.windyWindow = w
  win.winBounds = rect(0, 0, 1024, 768)
  gui.windows.add(win)

  echo "Mega Gallery is running with 46 functional widgets!"

  while not w.closeRequested:
    gui.updateAndDraw()
    w.swapBuffers()
    pollEvents()

if isMainModule:
  main()
