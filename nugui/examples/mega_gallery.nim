import nugui/core, nugui/widgets, nugui/textedit, nugui/dsl, nugui/renderer, nugui/theme, windy, pixie, vmath, opengl

proc main() =
  let gui = newSvgGui()
  initDefaultTheme()

  let win = uiWindow "Nugui Professional Mega Gallery":
    uiNavbar "NUGUI PLATFORM":
      uiRow:
        uiButton "Home", proc() = echo "Home clicked"
        uiButton "Components", proc() = echo "Showing components"
        uiAvatar "JS"

    uiRow:
      uiSidebar:
        uiColumn:
          uiTreeView:
            uiTreeItem "Input Suite":
              uiTreeItem "Basic Buttons"
              uiTreeItem "Checkboxes"
            uiTreeItem "Advanced":
              uiTreeItem "DataGrid"
              uiTreeItem "Pickers"
          uiButton "Exit", proc() = quit()

      uiScrollArea:
        uiColumn:
          uiRow:
            uiCard "Interactive Controls":
              uiColumn:
                uiButton "Primary Action", proc() = echo "Action triggered!"
                uiCheckbox "Enable Logic", true
                uiSlider 0.85, proc(v: float32) = echo "Slider: ", v
                uiSwitch "High Performance", true

            uiCard "Status & Info":
              uiColumn:
                uiRow:
                  uiBadge "STABLE"
                  uiTag "V2.0"
                uiProgressBar 0.65
                uiSpinner()
                uiRating 4
                uiSkeleton()

          uiRow:
            uiCard "Navigation & Lists":
              uiColumn:
                uiBreadcrumbs @["Home", "Projects", "Nugui"]
                uiPagination 5
                uiSteps @["Design", "Code", "Ship"]
                uiTabs @["Source", "Tests", "Docs"], proc(i: int) = echo "Tab: ", i

          uiRow:
            uiCard "Selection Form":
              uiColumn:
                uiTextBox "Edit your name..."
                uiSearchInput()
                uiComboBox @["Choose Language", "Nim", "C++", "Python", "Rust", "Go", "Zig"]

          uiDataGrid(@["NAME", "ROLE", "STATUS"], @[
            @["Jules", "Lead Architect", "Online"],
            @["Treeform", "Graphics Core", "Busy"],
            @["Windy", "Windowing", "Idle"]
          ])

          uiRow:
            uiDatePicker()
            uiColumn:
                uiLabel "Select Theme Color"
                uiColorPicker()

  let w = newWindow("Nugui Mega Gallery", ivec2(1280, 800))
  win.windyWindow = w
  win.winBounds = rect(0, 0, 1280, 800)
  gui.windows.add(win)

  w.onEvent = proc(event: Event) =
    gui.handleWindyEvent(win, event)

  loadExtensions()

  echo "Mega Gallery is live! Every widget shown is fully functional with real Nim logic."

  while not w.closeRequested:
    pollEvents()
    gui.updateAndDraw()
