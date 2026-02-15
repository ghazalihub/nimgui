import nugui/core, nugui/widgets, nugui/textedit, nugui/dsl, nugui/renderer, windy, pixie, vmath

proc main() =
  let gui = newSvgGui()

  let win = uiWindow "Nugui Component Gallery":
    uiColumn:
      uiRow:
        uiLabel "Buttons & Inputs:"
        uiButton "Primary"
        uiButton "Secondary"
        uiCheckbox true
        uiToggle true

      uiRow:
        uiLabel "Value Controls:"
        uiSlider 0.5
        uiProgressBar 0.75
        # uiRating 4

      uiRow:
        uiLabel "Data Views:"
        uiTabs @["Home", "Profile", "Settings"]
        # uiListView @["Item 1", "Item 2", "Item 3"]

  echo "Gallery created with components!"

if isMainModule:
  main()
