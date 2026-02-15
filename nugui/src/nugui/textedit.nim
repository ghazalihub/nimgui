import core, pixie, vmath, unicode, layout, strutils

type
  TextEdit* = ref object of Widget
    text*: string
    cursorPos*: int # Rune index
    selectionStart*: int
    selectionEnd*: int
    onChanged*: proc(text: string) {.gcsafe.}
    showCursor*: bool

proc runes(te: TextEdit): seq[Rune] =
  te.text.toRunes()

proc updateNodeText(te: TextEdit) =
  SvgText(te.node).text = te.text

proc newTextEdit*(text: string = ""): TextEdit =
  let te = TextEdit(text: text, cursorPos: text.toRunes().len, selectionStart: -1, selectionEnd: -1, showCursor: true)
  te.node = newSvgText()
  te.updateNodeText()
  te.enabled = true
  te.visible = true
  te.isFocusable = true

  te.onEvent = proc(w: Widget, ev: GuiEvent): bool =
    let te = TextEdit(w)
    case ev.kind
    of evKeyDown:
      let runes = te.runes()
      case ev.keyCode
      of KeyLeft:
        if te.cursorPos > 0: te.cursorPos -= 1
        return true
      of KeyRight:
        if te.cursorPos < runes.len: te.cursorPos += 1
        return true
      of KeyBackspace:
        if te.cursorPos > 0:
          var r = runes
          r.delete(te.cursorPos - 1)
          te.text = r.string
          te.cursorPos -= 1
          te.updateNodeText()
          if te.onChanged != nil: te.onChanged(te.text)
        return true
      of KeyDelete:
        if te.cursorPos < runes.len:
          var r = runes
          r.delete(te.cursorPos)
          te.text = r.string
          te.updateNodeText()
          if te.onChanged != nil: te.onChanged(te.text)
        return true
      of KeyEnter:
        # Handle enter if multi-line
        discard
      else: discard
    of evClick:
      # Set focus
      w.gui.setFocused(w, ReasonPressed)
      return true
    else: discard
    return false
  return te

proc insertChar*(te: TextEdit, c: Rune) =
  var r = te.runes()
  r.insert(c, te.cursorPos)
  te.text = r.string
  te.cursorPos += 1
  te.updateNodeText()
  if te.onChanged != nil: te.onChanged(te.text)
