import pixie, figdraw, figdraw/fignodes, figdraw/commons, chroma, vmath, core, layout, theme, tables, strutils

proc renderWindow*(win: Window): Image =
  # Properly render the window using Pixie
  result = newImage(win.winBounds.w.int, win.winBounds.h.int)
  result.fill(rgba(48, 48, 48, 255))

  # Recursively draw the SVG tree starting from the window node
  # Pixie's draw(Image, SvgNode) handles the heavy lifting
  result.draw(win.node)

proc updateAndDraw*(gui: SvgGui) =
  gui.processTimers()
  gui.layoutCtx.resetContext()
  for win in gui.windows:
    # 1. Prepare Layout tree
    let rootId = gui.layoutCtx.prepareLayout(win)

    # 2. Set root size
    gui.layoutCtx.setSize(rootId, [win.winBounds.w, win.winBounds.h])

    # 3. Run Layout calculation
    gui.layoutCtx.runContext()

    # 4. Apply calculated rects back to widgets and their SVG nodes
    gui.layoutCtx.applyLayout(win)

    # 5. Apply CSS styles based on new states/classes
    applyStyles(win)

    # 6. Render to window buffer
    let img = renderWindow(win)
    # The application main loop would then copy this 'img' to the Windy window
    # e.g. win.windyWindow.onFrame = proc() = ...
    discard
