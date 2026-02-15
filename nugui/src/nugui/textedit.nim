import core, pixie, vmath, unicode, layout, strutils, theme

type
  TextEdit* = ref object of Widget
    text*: string
    cursorPos*: int # Rune index
    selectionStart*: int # Rune index, -1 if no selection
    selectionEnd*: int
    onChanged*: proc(text: string) {.gcsafe.}
    undoStack*: seq[string]
    redoStack*: seq[string]
    cursorWidget*: Widget
    selectionWidget*: Widget

proc runes(te: TextEdit): seq[Rune] =
  te.text.toRunes()

proc updateNodeText(te: TextEdit) =
  if te.node != nil and te.node of SvgText:
    SvgText(te.node).text = te.text
  # Update cursor pos (mock for now, need font metrics)
  if te.cursorWidget != nil:
    te.cursorWidget.computedRect.x = te.cursorPos.float32 * 8.0f # Mock spacing

proc saveUndo*(te: TextEdit) =
  te.undoStack.add(te.text)
  te.redoStack.setLen(0)

proc undo*(te: TextEdit) =
  if te.undoStack.len > 0:
    te.redoStack.add(te.text)
    te.text = te.undoStack.pop()
    te.updateNodeText()

proc newTextEdit*(text: string = ""): TextEdit =
  result = TextEdit(text: text, cursorPos: text.toRunes().len, selectionStart: -1)
  result.node = newSvgText()
  result.updateNodeText()
  result.enabled = true
  result.visible = true
  result.isFocusable = true
  result.addClass("textedit")

  # Selection background
  result.selectionWidget = newWidget(newSvgRect())
  result.selectionWidget.addClass("text-selection")
  result.selectionWidget.visible = false
  result.addChild(result.selectionWidget)

  # Cursor
  result.cursorWidget = newWidget(newSvgRect())
  result.cursorWidget.addClass("text-cursor")
  result.addChild(result.cursorWidget)

  result.onEvent = proc(w: Widget, ev: GuiEvent): bool =
    let te = TextEdit(w)
    case ev.kind
    of evKeyDown:
      let runes = te.runes()
      case ev.keyCode
      of KeyLeft:
        if te.cursorPos > 0: te.cursorPos -= 1
        te.updateNodeText()
        return true
      of KeyRight:
        if te.cursorPos < runes.len: te.cursorPos += 1
        te.updateNodeText()
        return true
      of KeyBackspace:
        if te.cursorPos > 0:
          te.saveUndo()
          var r = runes
          r.delete(te.cursorPos - 1)
          te.text = r.string
          te.cursorPos -= 1
          te.updateNodeText()
          if te.onChanged != nil: te.onChanged(te.text)
        return true
      of KeyDelete:
        if te.cursorPos < runes.len:
          te.saveUndo()
          var r = runes
          r.delete(te.cursorPos)
          te.text = r.string
          te.updateNodeText()
          if te.onChanged != nil: te.onChanged(te.text)
        return true
      of KeyZ:
        # Check Ctrl
        te.undo()
        return true
      else: discard
    of evClick:
      w.gui.setFocused(w, ReasonPressed)
      return true
    else: discard
    return false

proc insertChar*(te: TextEdit, c: Rune) =
  te.saveUndo()
  var r = te.runes()
  r.insert(c, te.cursorPos)
  te.text = r.string
  te.cursorPos += 1
  te.updateNodeText()
  if te.onChanged != nil: te.onChanged(te.text)
