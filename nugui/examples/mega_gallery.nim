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
          uiButton "Exit", proc() = quit()

      uiScrollArea:
        uiColumn:
          uiRow:
            uiCard "Interactive":
              uiColumn:
                uiButton "Click Me", proc() = echo "Button was clicked!"
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
                uiComboBox @["Select Language", "Nim", "C++", "Python", "Rust"]

          uiDataGrid(@["ID", "Name", "Status"], @[
            @["1", "Alice", "Online"],
            @["2", "Bob", "Away"],
            @["3", "Charlie", "Offline"]
          ])

          uiRow:
            uiDatePicker()
            uiColumn:
                uiLabel "Pick a color"
                uiColorPicker()

  let w = newWindow("Nugui Mega Gallery", ivec2(1280, 800))
  win.windyWindow = w
  win.winBounds = rect(0, 0, 1280, 800)
  gui.windows.add(win)

  w.onEvent = proc(event: Event) =
    gui.handleWindyEvent(win, event)

  loadExtensions()

  echo "Ultimate Gallery is live with functional ComboBox, DataGrid, and more!"

  while not w.closeRequested:
    pollEvents()
    gui.updateAndDraw()
