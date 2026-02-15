import core, pixie, vmath, unicode, layout

type
  TextEdit* = ref object of Widget
    text*: string
    cursorPos*: int # byte index
    selectionStart*: int
    selectionEnd*: int
    onChanged*: proc(text: string) {.gcsafe.}

proc newTextEdit*(text: string = ""): TextEdit =
  new(result)
  result.node = newSvgText()
  result.text = text
  result.enabled = true
  result.visible = true
  result.isFocusable = true

proc insertChar*(te: TextEdit, c: Rune) =
  te.text.add($c) # Simplified
  if te.onChanged != nil: te.onChanged(te.text)

proc handleKeyDown*(te: TextEdit, ev: GuiEvent): bool =
  # Port logic for backspace etc.
  return true
