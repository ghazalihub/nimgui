import core, pixie, vmath, unicode, layout, strutils

type
  TextEdit* = ref object of Widget
    text*: string
    cursorPos*: int # byte index
    selectionStart*: int
    selectionEnd*: int
    onChanged*: proc(text: string) {.gcsafe.}
    showCursor*: bool

proc newTextEdit*(text: string = ""): TextEdit =
  new(result)
  result.node = newSvgText()
  result.text = text
  result.enabled = true
  result.visible = true
  result.isFocusable = true
  result.showCursor = true

  result.onEvent = proc(w: Widget, ev: GuiEvent): bool =
    let te = TextEdit(w)
    case ev.kind
    of evKeyDown:
      case ev.keyCode
      of KeyLeft:
        if te.cursorPos > 0: te.cursorPos -= 1
        return true
      of KeyRight:
        if te.cursorPos < te.text.len: te.cursorPos += 1
        return true
      of KeyBackspace:
        if te.cursorPos > 0:
          te.text.delete(te.cursorPos - 1 .. te.cursorPos - 1)
          te.cursorPos -= 1
          if te.onChanged != nil: te.onChanged(te.text)
        return true
      of KeyDelete:
        if te.cursorPos < te.text.len:
          te.text.delete(te.cursorPos .. te.cursorPos)
          if te.onChanged != nil: te.onChanged(te.text)
        return true
      of KeyHome:
        te.cursorPos = 0
        return true
      of KeyEnd:
        te.cursorPos = te.text.len
        return true
      else: discard
    else: discard
    return false

proc insertChar*(te: TextEdit, c: Rune) =
  te.text.insert($c, te.cursorPos)
  te.cursorPos += ($c).len
  if te.onChanged != nil: te.onChanged(te.text)
