import core, pixie, vmath, unicode, strutils

type
  TextEditor* = ref object
    text*: string
    cursorPos*: int # Rune index
    selectionStart*: int
    undoStack*: seq[string]
    redoStack*: seq[string]

proc runes*(te: TextEditor): seq[Rune] =
  te.text.toRunes()

proc setText*(te: TextEditor, s: string) =
  te.text = s
  te.cursorPos = s.toRunes().len

proc insert*(te: TextEditor, s: string) =
  te.undoStack.add(te.text)
  te.redoStack.setLen(0)
  var r = te.runes()
  let ins = s.toRunes()
  for i, rune in ins:
    r.insert(rune, te.cursorPos + i)
  te.text = r.string
  te.cursorPos += ins.len

proc backspace*(te: TextEditor) =
  if te.cursorPos > 0:
    te.undoStack.add(te.text)
    var r = te.runes()
    r.delete(te.cursorPos - 1)
    te.text = r.string
    te.cursorPos -= 1

proc delete*(te: TextEditor) =
  var r = te.runes()
  if te.cursorPos < r.len:
    te.undoStack.add(te.text)
    r.delete(te.cursorPos)
    te.text = r.string

proc handleKey*(te: TextEditor, key: Key, mods: set[Modifier]) =
  case key
  of KeyLeft:
    if te.cursorPos > 0: te.cursorPos -= 1
  of KeyRight:
    var r = te.runes()
    if te.cursorPos < r.len: te.cursorPos += 1
  of KeyBackspace:
    te.backspace()
  of KeyDelete:
    te.delete()
  of KeyHome:
    te.cursorPos = 0
  of KeyEnd:
    te.cursorPos = te.runes().len
  of KeyZ:
    if mCtrl in mods:
        if te.undoStack.len > 0:
            te.redoStack.add(te.text)
            te.text = te.undoStack.pop()
            te.cursorPos = te.text.toRunes().len
  of KeyY:
    if mCtrl in mods:
        if te.redoStack.len > 0:
            te.undoStack.add(te.text)
            te.text = te.redoStack.pop()
            te.cursorPos = te.text.toRunes().len
  else: discard

proc newTextEditor*(): TextEditor =
  result = TextEditor(text: "", cursorPos: 0, selectionStart: -1)
