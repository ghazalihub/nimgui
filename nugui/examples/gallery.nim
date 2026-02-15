import nugui/core, nugui/widgets, nugui/textedit, nugui/dsl, nugui/renderer, windy, pixie, vmath

proc main() =
  let gui = newSvgGui()

  let win = uiWindow "Nugui Component Gallery":
    uiColumn:
      uiRow:
        uiLabel "Buttons:"
        uiButton "Primary Action", proc() = echo "Clicked Primary!"
        uiButton "Secondary", proc() = echo "Clicked Secondary!"

      uiRow:
        uiLabel "Controls:"
        uiCheckbox "Enable Feature", true
        uiSlider 0.5, proc(v: float32) = echo "Slider: ", v

      uiRow:
        uiLabel "Text Entry:"
        uiTextEdit "Edit me...", proc(t: string) = echo "Text changed: ", t

      uiRow:
        uiLabel "Navigation:"
        uiTabs @["Dashboard", "Reports", "Analytics"]

  # Windy window setup
  let w = newWindow("Nugui Gallery", ivec2(800, 600))
  win.windyWindow = w
  gui.windows.add(win)

  while not w.closeRequested:
    gui.processEvents()
    gui.draw()
    # Rendering would use pixie to draw win.node to w's framebuffer
    w.swapBuffers()
    pollEvents()

  echo "Application finished."

if isMainModule:
  main()
