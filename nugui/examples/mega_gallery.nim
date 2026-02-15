import nugui/core, nugui/widgets, nugui/textedit, nugui/dsl, nugui/renderer, nugui/theme, windy, pixie, vmath, opengl

proc main() =
  let gui = newSvgGui()
  initDefaultTheme()

  let win = uiWindow "Nugui Ultimate Mega Gallery":
    uiNavbar "NUGUI":
      uiRow:
        uiButton "Home"
        uiButton "Components"
        uiAvatar "JS"

    uiRow:
      uiSidebar:
        uiColumn:
          uiTreeView:
            uiTreeItem "Inputs":
              uiTreeItem "Buttons"
              uiTreeItem "Checkboxes"
          uiButton "Exit"

      uiScrollArea:
        uiColumn:
          uiRow:
            uiCard "Interactive":
              uiColumn:
                uiButton "Click Me", proc() = echo "Clicked!"
                uiCheckbox "Check Me", true
                uiSlider 0.75
                uiSwitch "Toggle", true

            uiCard "Status":
              uiColumn:
                uiBadge "New"
                uiProgressBar 0.45
                uiSpinner()

          uiRow:
            uiCard "Forms":
              uiColumn:
                uiTextBox "Edit Me"
                uiSearchInput()
                uiComboBox @["Option 1", "Option 2"]

          uiDataGrid(@["ID", "Name"], @[@["1", "Alice"], @["2", "Bob"]])

  let w = newWindow("Nugui Mega Gallery", ivec2(1280, 800))
  win.windyWindow = w
  win.winBounds = rect(0, 0, 1280, 800)
  gui.windows.add(win)

  # Hook up events
  w.onEvent = proc(event: Event) =
    gui.handleWindyEvent(win, event)

  loadExtensions() # For OpenGL

  echo "Ultimate Gallery is live!"

  while not w.closeRequested:
    pollEvents()
    gui.updateAndDraw()
    # sleep(1) # Optional to save CPU
