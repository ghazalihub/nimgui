type
  LayId* = uint32
  LayScalar* = float32

const
  LayInvalidId* = high(uint32)

type
  LayVec4* = array[4, LayScalar]
  LayVec2* = array[2, LayScalar]

  LayItem* = object
    flags*: uint32
    firstChild*: LayId
    nextSibling*: LayId
    margins*: LayVec4
    size*: LayVec2

  LayContext* = object
    items*: seq[LayItem]
    rects*: seq[LayVec4]

  LayBoxFlags* = enum
    LAY_ROW = 0x002
    LAY_COLUMN = 0x003
    LAY_LAYOUT = 0x000
    LAY_FLEX = 0x002
    LAY_NOWRAP = 0x000
    LAY_WRAP = 0x004
    LAY_START = 0x008
    LAY_MIDDLE = 0x000
    LAY_END = 0x010
    LAY_JUSTIFY = 0x018

  LayLayoutFlags* = enum
    LAY_LEFT = 0x020
    LAY_TOP = 0x040
    LAY_RIGHT = 0x080
    LAY_BOTTOM = 0x100
    LAY_HFILL = 0x0a0
    LAY_VFILL = 0x140
    LAY_HCENTER = 0x000
    LAY_VCENTER = 0x000
    LAY_CENTER = 0x000
    LAY_FILL = 0x1e0
    LAY_BREAK = 0x200

const
  LAY_ITEM_BOX_MODEL_MASK = 0x000007u32
  LAY_ITEM_BOX_MASK = 0x00001Fu32
  LAY_ITEM_LAYOUT_MASK = 0x0003E0u32
  LAY_ITEM_INSERTED = 0x400u32
  LAY_ITEM_HFIXED = 0x800u32
  LAY_ITEM_VFIXED = 0x1000u32
  LAY_ITEM_FIXED_MASK = LAY_ITEM_HFIXED or LAY_ITEM_VFIXED

proc initContext*(ctx: var LayContext) =
  ctx.items = @[]
  ctx.rects = @[]

proc newLayoutContext*(): LayContext =
  initContext(result)

proc reserveItemsCapacity*(ctx: var LayContext, count: int) =
  ctx.items.reserveCapacity(count)
  ctx.rects.reserveCapacity(count)

proc resetContext*(ctx: var LayContext) =
  ctx.items.setLen(0)
  ctx.rects.setLen(0)

proc item*(ctx: var LayContext): LayId =
  let idx = ctx.items.len.uint32
  ctx.items.add(LayItem(firstChild: LayInvalidId, nextSibling: LayInvalidId))
  ctx.rects.add([0f32, 0, 0, 0])
  return idx

proc appendByPtr(ctx: var LayContext, earlier: LayId, later: LayId) =
  ctx.items[later].nextSibling = ctx.items[earlier].nextSibling
  ctx.items[later].flags = ctx.items[later].flags or LAY_ITEM_INSERTED
  ctx.items[earlier].nextSibling = later

proc insert*(ctx: var LayContext, parent: LayId, child: LayId) =
  if ctx.items[parent].firstChild == LayInvalidId:
    ctx.items[parent].firstChild = child
    ctx.items[child].flags = ctx.items[child].flags or LAY_ITEM_INSERTED
  else:
    var last = ctx.items[parent].firstChild
    while ctx.items[last].nextSibling != LayInvalidId:
      last = ctx.items[last].nextSibling
    appendByPtr(ctx, last, child)

proc push*(ctx: var LayContext, parent: LayId, child: LayId) =
  let oldChild = ctx.items[parent].firstChild
  ctx.items[parent].firstChild = child
  ctx.items[child].flags = ctx.items[child].flags or LAY_ITEM_INSERTED
  ctx.items[child].nextSibling = oldChild

proc setSize*(ctx: var LayContext, item: LayId, size: LayVec2) =
  ctx.items[item].size = size
  if size[0] == 0:
    ctx.items[item].flags = ctx.items[item].flags and (not LAY_ITEM_HFIXED)
  else:
    ctx.items[item].flags = ctx.items[item].flags or LAY_ITEM_HFIXED
  if size[1] == 0:
    ctx.items[item].flags = ctx.items[item].flags and (not LAY_ITEM_VFIXED)
  else:
    ctx.items[item].flags = ctx.items[item].flags or LAY_ITEM_VFIXED

proc setContain*(ctx: var LayContext, item: LayId, flags: uint32) =
  ctx.items[item].flags = (ctx.items[item].flags and (not LAY_ITEM_BOX_MASK)) or (flags and LAY_ITEM_BOX_MASK)

proc setBehave*(ctx: var LayContext, item: LayId, flags: uint32) =
  ctx.items[item].flags = (ctx.items[item].flags and (not LAY_ITEM_LAYOUT_MASK)) or (flags and LAY_ITEM_LAYOUT_MASK)

proc setMargins*(ctx: var LayContext, item: LayId, ltrb: LayVec4) =
  ctx.items[item].margins = ltrb

proc getRect*(ctx: LayContext, item: LayId): LayVec4 =
  ctx.rects[item]

# --- Calculation logic ---

proc calcOverlayedSize(ctx: var LayContext, item: LayId, dim: int): LayScalar =
  let wdim = dim + 2
  var needSize: LayScalar = 0
  var child = ctx.items[item].firstChild
  while child != LayInvalidId:
    let childSize = ctx.rects[child][dim] + ctx.rects[child][dim + 2] + ctx.items[child].margins[wdim]
    needSize = max(needSize, childSize)
    child = ctx.items[child].nextSibling
  return needSize

proc calcStackedSize(ctx: var LayContext, item: LayId, dim: int): LayScalar =
  let wdim = dim + 2
  var needSize: LayScalar = 0
  var child = ctx.items[item].firstChild
  while child != LayInvalidId:
    needSize += ctx.rects[child][dim] + ctx.rects[child][dim + 2] + ctx.items[child].margins[wdim]
    child = ctx.items[child].nextSibling
  return needSize

proc calcWrappedOverlayedSize(ctx: var LayContext, item: LayId, dim: int): LayScalar =
  let wdim = dim + 2
  var needSize: LayScalar = 0
  var needSize2: LayScalar = 0
  var child = ctx.items[item].firstChild
  while child != LayInvalidId:
    if (ctx.items[child].flags and uint32(LAY_BREAK)) != 0:
      needSize2 += needSize
      needSize = 0
    let childSize = ctx.rects[child][dim] + ctx.rects[child][dim + 2] + ctx.items[child].margins[wdim]
    needSize = max(needSize, childSize)
    child = ctx.items[child].nextSibling
  return needSize2 + needSize

proc calcWrappedStackedSize(ctx: var LayContext, item: LayId, dim: int): LayScalar =
  let wdim = dim + 2
  var needSize: LayScalar = 0
  var needSize2: LayScalar = 0
  var child = ctx.items[item].firstChild
  while child != LayInvalidId:
    if (ctx.items[child].flags and uint32(LAY_BREAK)) != 0:
      needSize2 = max(needSize2, needSize)
      needSize = 0
    needSize += ctx.rects[child][dim] + ctx.rects[child][dim + 2] + ctx.items[child].margins[wdim]
    child = ctx.items[child].nextSibling
  return max(needSize2, needSize)

proc calcSize(ctx: var LayContext, item: LayId, dim: int) =
  var child = ctx.items[item].firstChild
  while child != LayInvalidId:
    calcSize(ctx, child, dim)
    child = ctx.items[child].nextSibling

  ctx.rects[item][dim] = ctx.items[item].margins[dim]
  if ctx.items[item].size[dim] != 0:
    ctx.rects[item][dim + 2] = ctx.items[item].size[dim]
    return

  var calSize: LayScalar
  let model = ctx.items[item].flags and LAY_ITEM_BOX_MODEL_MASK
  case model
  of uint32(LAY_COLUMN) or uint32(LAY_WRAP):
    if dim != 0: calSize = calcStackedSize(ctx, item, 1)
    else: calSize = calcOverlayedSize(ctx, item, 0)
  of uint32(LAY_ROW) or uint32(LAY_WRAP):
    if dim == 0: calSize = calcWrappedStackedSize(ctx, item, 0)
    else: calSize = calcWrappedOverlayedSize(ctx, item, 1)
  of uint32(LAY_COLUMN), uint32(LAY_ROW):
    if (ctx.items[item].flags and 1u32) == dim.uint32:
      calSize = calcStackedSize(ctx, item, dim)
    else:
      calSize = calcOverlayedSize(ctx, item, dim)
  else:
    calSize = calcOverlayedSize(ctx, item, dim)

  ctx.rects[item][dim + 2] = calSize

proc arrangeOverlaySqueezedRange(ctx: var LayContext, dim: int, startItem: LayId, endItem: LayId, offset: LayScalar, space: LayScalar) =
  let wdim = dim + 2
  var item = startItem
  while item != endItem:
    let bflags = (ctx.items[item].flags and LAY_ITEM_LAYOUT_MASK) shr dim
    let margins = ctx.items[item].margins
    var rect = ctx.rects[item]
    let minSize = max(0f32, space - rect[dim] - margins[wdim])

    case bflags and uint32(LAY_HFILL)
    of uint32(LAY_HCENTER):
      rect[dim + 2] = min(rect[dim + 2], minSize)
      rect[dim] += (space - rect[dim + 2]) / 2 - margins[wdim]
    of uint32(LAY_RIGHT):
      rect[dim + 2] = min(rect[dim + 2], minSize)
      rect[dim] = space - rect[dim + 2] - margins[wdim]
    of uint32(LAY_HFILL):
      rect[dim + 2] = minSize
    else:
      rect[dim + 2] = min(rect[dim + 2], minSize)

    rect[dim] += offset
    ctx.rects[item] = rect
    item = ctx.items[item].nextSibling

proc arrangeWrappedOverlaySqueezed(ctx: var LayContext, item: LayId, dim: int): LayScalar =
  let wdim = dim + 2
  var offset = ctx.rects[item][dim]
  var needSize: LayScalar = 0
  var child = ctx.items[item].firstChild
  var startChild = child
  while child != LayInvalidId:
    if (ctx.items[child].flags and uint32(LAY_BREAK)) != 0:
      arrangeOverlaySqueezedRange(ctx, dim, startChild, child, offset, needSize)
      offset += needSize
      startChild = child
      needSize = 0
    let childSize = ctx.rects[child][dim] + ctx.rects[child][dim + 2] + ctx.items[child].margins[wdim]
    needSize = max(needSize, childSize)
    child = ctx.items[child].nextSibling
  arrangeOverlaySqueezedRange(ctx, dim, startChild, LayInvalidId, offset, needSize)
  offset += needSize
  return offset

proc arrangeStacked(ctx: var LayContext, item: LayId, dim: int, wrap: bool) =
  let wdim = dim + 2
  let itemFlags = ctx.items[item].flags
  let rect = ctx.rects[item]
  let space = rect[dim + 2]
  let maxX2 = rect[dim] + space

  var startChild = ctx.items[item].firstChild
  while startChild != LayInvalidId:
    var used: LayScalar = 0
    var count: uint32 = 0
    var squeezedCount: uint32 = 0
    var total: uint32 = 0
    var hardbreak = false

    var child = startChild
    var endChild = LayInvalidId
    while child != LayInvalidId:
      let childFlags = ctx.items[child].flags
      let flags = (childFlags and LAY_ITEM_LAYOUT_MASK) shr dim
      let fflags = (childFlags and LAY_ITEM_FIXED_MASK) shr dim
      let childMargins = ctx.items[child].margins
      let childRect = ctx.rects[child]
      var extend = used

      if (flags and uint32(LAY_HFILL)) == uint32(LAY_HFILL):
        count += 1
        extend += childRect[dim] + childMargins[wdim]
      else:
        if (fflags and uint32(LAY_ITEM_HFIXED)) != uint32(LAY_ITEM_HFIXED):
          squeezedCount += 1
        extend += childRect[dim] + childRect[dim + 2] + childMargins[wdim]

      if wrap and total > 0 and (extend > space or (childFlags and uint32(LAY_BREAK)) != 0):
        endChild = child
        hardbreak = (childFlags and uint32(LAY_BREAK)) != 0
        ctx.items[child].flags = childFlags or uint32(LAY_BREAK)
        break
      else:
        used = extend
        child = ctx.items[child].nextSibling
      total += 1

    let extraSpace = space - used
    var filler: float32 = 0
    var spacer: float32 = 0
    var extraMargin: float32 = 0
    var eater: float32 = 0

    if extraSpace > 0:
      if count > 0:
        filler = extraSpace / count.float32
      elif total > 0:
        case itemFlags and uint32(LAY_JUSTIFY)
        of uint32(LAY_JUSTIFY):
          if not wrap or (endChild != LayInvalidId and not hardbreak):
            spacer = extraSpace / (total - 1).float32
        of uint32(LAY_START): discard
        of uint32(LAY_END):
          extraMargin = extraSpace
        else:
          extraMargin = extraSpace / 2.0
    elif not wrap and squeezedCount > 0:
      eater = extraSpace / squeezedCount.float32

    var x = rect[dim]
    child = startChild
    while child != endChild:
      let pchild = addr ctx.items[child]
      let flags = (pchild.flags and LAY_ITEM_LAYOUT_MASK) shr dim
      let fflags = (pchild.flags and LAY_ITEM_FIXED_MASK) shr dim
      let childMargins = pchild.margins
      var childRect = ctx.rects[child]

      x += childRect[dim] + extraMargin
      var x1: float32
      if (flags and uint32(LAY_HFILL)) == uint32(LAY_HFILL):
        x1 = x + filler
      elif (fflags and uint32(LAY_ITEM_HFIXED)) == uint32(LAY_ITEM_HFIXED):
        x1 = x + childRect[dim + 2]
      else:
        x1 = x + max(0f32, childRect[dim + 2] + eater)

      let ix0 = x
      let ix1 = if wrap: min(maxX2 - childMargins[wdim], x1) else: x1
      ctx.rects[child][dim] = ix0
      ctx.rects[child][dim + 2] = ix1 - ix0
      x = x1 + childMargins[wdim]
      child = pchild.nextSibling
      extraMargin = spacer

    startChild = endChild

proc arrangeOverlay(ctx: var LayContext, item: LayId, dim: int) =
  let wdim = dim + 2
  let rect = ctx.rects[item]
  let offset = rect[dim]
  let space = rect[dim + 2]

  var child = ctx.items[item].firstChild
  while child != LayInvalidId:
    let bflags = (ctx.items[child].flags and LAY_ITEM_LAYOUT_MASK) shr dim
    let childMargins = ctx.items[child].margins
    var childRect = ctx.rects[child]

    case bflags and uint32(LAY_HFILL)
    of uint32(LAY_HCENTER):
      childRect[dim] += (space - childRect[dim + 2]) / 2 - childMargins[wdim]
    of uint32(LAY_RIGHT):
      childRect[dim] += space - childRect[dim + 2] - childMargins[dim] - childMargins[wdim]
    of uint32(LAY_HFILL):
      childRect[dim + 2] = max(0f32, space - childRect[dim] - childMargins[wdim])
    else: discard

    childRect[dim] += offset
    ctx.rects[child] = childRect
    child = ctx.items[child].nextSibling

proc arrange(ctx: var LayContext, item: LayId, dim: int) =
  let flags = ctx.items[item].flags
  let model = flags and LAY_ITEM_BOX_MODEL_MASK

  case model
  of uint32(LAY_COLUMN) or uint32(LAY_WRAP):
    if dim != 0:
      arrangeStacked(ctx, item, 1, true)
      let offset = arrangeWrappedOverlaySqueezed(ctx, item, 0)
      ctx.rects[item][2] = offset - ctx.rects[item][0]
  of uint32(LAY_ROW) or uint32(LAY_WRAP):
    if dim == 0:
      arrangeStacked(ctx, item, 0, true)
    else:
      discard arrangeWrappedOverlaySqueezed(ctx, item, 1)
  of uint32(LAY_COLUMN), uint32(LAY_ROW):
    if (flags and 1u32) == dim.uint32:
      arrangeStacked(ctx, item, dim, false)
    else:
      arrangeOverlaySqueezedRange(ctx, dim, ctx.items[item].firstChild, LayInvalidId, ctx.rects[item][dim], ctx.rects[item][dim + 2])
  else:
    arrangeOverlay(ctx, item, dim)

  var child = ctx.items[item].firstChild
  while child != LayInvalidId:
    arrange(ctx, child, dim)
    child = ctx.items[child].nextSibling

proc runItem*(ctx: var LayContext, item: LayId) =
  calcSize(ctx, item, 0)
  arrange(ctx, item, 0)
  calcSize(ctx, item, 1)
  arrange(ctx, item, 1)

proc runContext*(ctx: var LayContext) =
  if ctx.items.len > 0:
    runItem(ctx, 0)
