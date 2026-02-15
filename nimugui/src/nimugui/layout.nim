# import vmath # Removed to avoid dependency issues

type
  lay_id* = uint32
  lay_scalar* = float32

const
  LAY_INVALID_ID* = lay_id.high

type
  lay_vec4* = array[4, lay_scalar]
  lay_vec2* = array[2, lay_scalar]

  lay_item_t* = object
    flags*: uint32
    first_child*: lay_id
    next_sibling*: lay_id
    margins*: lay_vec4
    size*: lay_vec2

  lay_context* = object
    items*: seq[lay_item_t]
    rects*: seq[lay_vec4]

const
  # Container flags
  LAY_ROW* = 0x002'u32
  LAY_COLUMN* = 0x003'u32
  LAY_LAYOUT* = 0x000'u32
  LAY_FLEX* = 0x002'u32
  LAY_NOWRAP* = 0x000'u32
  LAY_WRAP* = 0x004'u32
  LAY_START* = 0x008'u32
  LAY_MIDDLE* = 0x000'u32
  LAY_END* = 0x010'u32
  LAY_JUSTIFY* = 0x018'u32

  # Child layout flags
  LAY_LEFT* = 0x020'u32
  LAY_TOP* = 0x040'u32
  LAY_RIGHT* = 0x080'u32
  LAY_BOTTOM* = 0x100'u32
  LAY_HFILL* = 0x0a0'u32
  LAY_VFILL* = 0x140'u32
  LAY_HCENTER* = 0x000'u32
  LAY_VCENTER* = 0x000'u32
  LAY_CENTER* = 0x000'u32
  LAY_FILL* = 0x1e0'u32
  LAY_BREAK* = 0x200'u32

  LAY_USERMASK* = 0x7fff0000'u32
  LAY_ITEM_BOX_MODEL_MASK = 0x000007'u32
  LAY_ITEM_BOX_MASK       = 0x00001F'u32
  LAY_ITEM_LAYOUT_MASK    = 0x0003E0'u32
  LAY_ITEM_INSERTED       = 0x400'u32
  LAY_ITEM_HFIXED         = 0x800'u32
  LAY_ITEM_VFIXED         = 0x1000'u32
  LAY_ITEM_FIXED_MASK     = LAY_ITEM_HFIXED or LAY_ITEM_VFIXED

proc init_lay_context*(ctx: var lay_context) =
  ctx.items = @[]
  ctx.rects = @[]

proc lay_reset_context*(ctx: var lay_context) =
  ctx.items.setLen(0)
  ctx.rects.setLen(0)

proc lay_item*(ctx: var lay_context): lay_id =
  let id = ctx.items.len.lay_id
  ctx.items.add(lay_item_t(first_child: LAY_INVALID_ID, next_sibling: LAY_INVALID_ID))
  ctx.rects.add([0.lay_scalar, 0, 0, 0])
  return id

proc lay_insert*(ctx: var lay_context, parent, child: lay_id) =
  if parent == LAY_INVALID_ID or child == LAY_INVALID_ID: return
  if ctx.items[parent].first_child == LAY_INVALID_ID:
    ctx.items[parent].first_child = child
    ctx.items[child].flags = ctx.items[child].flags or LAY_ITEM_INSERTED
  else:
    var next = ctx.items[parent].first_child
    while true:
      if ctx.items[next].next_sibling == LAY_INVALID_ID:
        ctx.items[next].next_sibling = child
        ctx.items[child].flags = ctx.items[child].flags or LAY_ITEM_INSERTED
        break
      next = ctx.items[next].next_sibling

proc lay_push*(ctx: var lay_context, parent, child: lay_id) =
  if parent == LAY_INVALID_ID or child == LAY_INVALID_ID: return
  let old_child = ctx.items[parent].first_child
  ctx.items[parent].first_child = child
  ctx.items[child].flags = ctx.items[child].flags or LAY_ITEM_INSERTED
  ctx.items[child].next_sibling = old_child

proc lay_set_size_xy*(ctx: var lay_context, item: lay_id, width, height: lay_scalar) =
  ctx.items[item].size[0] = width
  ctx.items[item].size[1] = height
  if width == 0: ctx.items[item].flags = ctx.items[item].flags and (not LAY_ITEM_HFIXED)
  else: ctx.items[item].flags = ctx.items[item].flags or LAY_ITEM_HFIXED
  if height == 0: ctx.items[item].flags = ctx.items[item].flags and (not LAY_ITEM_VFIXED)
  else: ctx.items[item].flags = ctx.items[item].flags or LAY_ITEM_VFIXED

proc lay_set_contain*(ctx: var lay_context, item: lay_id, flags: uint32) =
  ctx.items[item].flags = (ctx.items[item].flags and (not LAY_ITEM_BOX_MASK)) or (flags and LAY_ITEM_BOX_MASK)

proc lay_set_behave*(ctx: var lay_context, item: lay_id, flags: uint32) =
  ctx.items[item].flags = (ctx.items[item].flags and (not LAY_ITEM_LAYOUT_MASK)) or (flags and LAY_ITEM_LAYOUT_MASK)

proc lay_set_margins_ltrb*(ctx: var lay_context, item: lay_id, l, t, r, b: lay_scalar) =
  ctx.items[item].margins = [l, t, r, b]

proc lay_get_rect*(ctx: lay_context, id: lay_id): lay_vec4 =
  return ctx.rects[id]

# Forward declarations
proc lay_calc_size(ctx: var lay_context, item: lay_id, dim: int)
proc lay_arrange(ctx: var lay_context, item: lay_id, dim: int)

proc lay_run_item*(ctx: var lay_context, item: lay_id) =
  lay_calc_size(ctx, item, 0)
  lay_arrange(ctx, item, 0)
  lay_calc_size(ctx, item, 1)
  lay_arrange(ctx, item, 1)

proc lay_run_context*(ctx: var lay_context) =
  if ctx.items.len > 0:
    lay_run_item(ctx, 0)

# Helper functions for calculations
proc lay_calc_overlayed_size(ctx: var lay_context, item: lay_id, dim: int): lay_scalar =
  let wdim = dim + 2
  var need_size: lay_scalar = 0
  var child = ctx.items[item].first_child
  while child != LAY_INVALID_ID:
    let child_size = ctx.rects[child][dim] + ctx.rects[child][2 + dim] + ctx.items[child].margins[wdim]
    need_size = max(need_size, child_size)
    child = ctx.items[child].next_sibling
  return need_size

proc lay_calc_stacked_size(ctx: var lay_context, item: lay_id, dim: int): lay_scalar =
  let wdim = dim + 2
  var need_size: lay_scalar = 0
  var child = ctx.items[item].first_child
  while child != LAY_INVALID_ID:
    need_size += ctx.rects[child][dim] + ctx.rects[child][2 + dim] + ctx.items[child].margins[wdim]
    child = ctx.items[child].next_sibling
  return need_size

proc lay_calc_wrapped_overlayed_size(ctx: var lay_context, item: lay_id, dim: int): lay_scalar =
  let wdim = dim + 2
  var need_size: lay_scalar = 0
  var need_size2: lay_scalar = 0
  var child = ctx.items[item].first_child
  while child != LAY_INVALID_ID:
    if (ctx.items[child].flags and LAY_BREAK) != 0:
      need_size2 += need_size
      need_size = 0
    let child_size = ctx.rects[child][dim] + ctx.rects[child][2 + dim] + ctx.items[child].margins[wdim]
    need_size = max(need_size, child_size)
    child = ctx.items[child].next_sibling
  return need_size2 + need_size

proc lay_calc_wrapped_stacked_size(ctx: var lay_context, item: lay_id, dim: int): lay_scalar =
  let wdim = dim + 2
  var need_size: lay_scalar = 0
  var need_size2: lay_scalar = 0
  var child = ctx.items[item].first_child
  while child != LAY_INVALID_ID:
    if (ctx.items[child].flags and LAY_BREAK) != 0:
      need_size2 = max(need_size2, need_size)
      need_size = 0
    need_size += ctx.rects[child][dim] + ctx.rects[child][2 + dim] + ctx.items[child].margins[wdim]
    child = ctx.items[child].next_sibling
  return max(need_size2, need_size)

proc lay_calc_size(ctx: var lay_context, item: lay_id, dim: int) =
  var child = ctx.items[item].first_child
  while child != LAY_INVALID_ID:
    lay_calc_size(ctx, child, dim)
    child = ctx.items[child].next_sibling

  let pitem = addr ctx.items[item]
  ctx.rects[item][dim] = pitem.margins[dim]

  if pitem.size[dim] != 0:
    ctx.rects[item][2 + dim] = pitem.size[dim]
    return

  var cal_size: lay_scalar = 0
  let model = pitem.flags and LAY_ITEM_BOX_MODEL_MASK
  if model == (LAY_COLUMN or LAY_WRAP):
    if dim != 0: cal_size = lay_calc_stacked_size(ctx, item, 1)
    else: cal_size = lay_calc_overlayed_size(ctx, item, 0)
  elif model == (LAY_ROW or LAY_WRAP):
    if dim == 0: cal_size = lay_calc_wrapped_stacked_size(ctx, item, 0)
    else: cal_size = lay_calc_wrapped_overlayed_size(ctx, item, 1)
  elif model == LAY_COLUMN or model == LAY_ROW:
    if (pitem.flags and 1) == uint32(dim):
      cal_size = lay_calc_stacked_size(ctx, item, dim)
    else:
      cal_size = lay_calc_overlayed_size(ctx, item, dim)
  else:
    cal_size = lay_calc_overlayed_size(ctx, item, dim)

  ctx.rects[item][2 + dim] = cal_size

proc lay_arrange_stacked(ctx: var lay_context, item: lay_id, dim: int, wrap: bool) =
  let wdim = dim + 2
  let item_flags = ctx.items[item].flags
  let rect = ctx.rects[item]
  let space = rect[2 + dim]
  let max_x2 = rect[dim] + space

  var start_child = ctx.items[item].first_child
  while start_child != LAY_INVALID_ID:
    var used: lay_scalar = 0
    var count: uint32 = 0
    var squeezed_count: uint32 = 0
    var total: uint32 = 0
    var hardbreak = false
    var child = start_child
    var end_child = LAY_INVALID_ID
    while child != LAY_INVALID_ID:
      let child_flags = ctx.items[child].flags
      let flags = (child_flags and LAY_ITEM_LAYOUT_MASK) shr dim
      let fflags = (child_flags and LAY_ITEM_FIXED_MASK) shr dim
      let child_margins = ctx.items[child].margins
      let child_rect = ctx.rects[child]
      var extend = used
      if (flags and LAY_HFILL) == LAY_HFILL:
        inc count
        extend += child_rect[dim] + child_margins[wdim]
      else:
        if (fflags and (LAY_ITEM_HFIXED shr dim)) != (LAY_ITEM_HFIXED shr dim):
          inc squeezed_count
        extend += child_rect[dim] + child_rect[2 + dim] + child_margins[wdim]

      if wrap and total != 0 and (extend > space or (child_flags and LAY_BREAK) != 0):
        end_child = child
        hardbreak = (child_flags and LAY_BREAK) != 0
        ctx.items[child].flags = child_flags or LAY_BREAK
        break
      else:
        used = extend
        child = ctx.items[child].next_sibling
      inc total

    let extra_space = space - used
    var filler: float32 = 0.0
    var spacer: float32 = 0.0
    var extra_margin: float32 = 0.0
    var eater: float32 = 0.0

    if extra_space > 0:
      if count > 0:
        filler = extra_space / count.float32
      elif total > 0:
        case item_flags and LAY_JUSTIFY:
        of LAY_JUSTIFY:
          if not wrap or (end_child != LAY_INVALID_ID and not hardbreak):
            if total > 1: spacer = extra_space / (total - 1).float32
        of LAY_START: discard
        of LAY_END: extra_margin = extra_space
        else: extra_margin = extra_space / 2.0
    elif not wrap and squeezed_count > 0:
      eater = extra_space / squeezed_count.float32

    var x = rect[dim].float32
    child = start_child
    while child != end_child:
      let child_flags = ctx.items[child].flags
      let flags = (child_flags and LAY_ITEM_LAYOUT_MASK) shr dim
      let fflags = (child_flags and LAY_ITEM_FIXED_MASK) shr dim
      let child_margins = ctx.items[child].margins
      var child_rect = ctx.rects[child]

      x += child_rect[dim] + extra_margin
      var x1: float32
      if (flags and LAY_HFILL) == LAY_HFILL:
        x1 = x + filler
      elif (fflags and (LAY_ITEM_HFIXED shr dim)) == (LAY_ITEM_HFIXED shr dim):
        x1 = x + child_rect[2 + dim]
      else:
        x1 = x + max(0.0.float32, child_rect[2 + dim] + eater)

      let ix0 = x.lay_scalar
      let ix1 = if wrap: min(max_x2 - child_margins[wdim], x1.lay_scalar) else: x1.lay_scalar
      child_rect[dim] = ix0
      child_rect[dim + 2] = ix1 - ix0
      ctx.rects[child] = child_rect
      x = x1 + child_margins[wdim]
      child = ctx.items[child].next_sibling
      extra_margin = spacer

    start_child = end_child

proc lay_arrange_overlay(ctx: var lay_context, item: lay_id, dim: int) =
  let wdim = dim + 2
  let rect = ctx.rects[item]
  let offset = rect[dim]
  let space = rect[2 + dim]

  var child = ctx.items[item].first_child
  while child != LAY_INVALID_ID:
    let b_flags = (ctx.items[child].flags and LAY_ITEM_LAYOUT_MASK) shr dim
    let child_margins = ctx.items[child].margins
    var child_rect = ctx.rects[child]

    let align = b_flags and LAY_HFILL
    if align == LAY_HCENTER:
      child_rect[dim] += (space - child_rect[2 + dim]) / 2 - child_margins[wdim]
    elif align == LAY_RIGHT:
      child_rect[dim] += space - child_rect[2 + dim] - child_margins[dim] - child_margins[wdim]
    elif align == LAY_HFILL:
      child_rect[2 + dim] = max(0.lay_scalar, space - child_rect[dim] - child_margins[wdim])

    child_rect[dim] += offset
    ctx.rects[child] = child_rect
    child = ctx.items[child].next_sibling

proc lay_arrange_overlay_squeezed_range(ctx: var lay_context, dim: int, start_item, end_item: lay_id, offset, space: lay_scalar) =
  let wdim = dim + 2
  var item = start_item
  while item != end_item:
    let b_flags = (ctx.items[item].flags and LAY_ITEM_LAYOUT_MASK) shr dim
    let margins = ctx.items[item].margins
    var rect = ctx.rects[item]
    let min_size = max(0.lay_scalar, space - rect[dim] - margins[wdim])
    let align = b_flags and LAY_HFILL
    if align == LAY_HCENTER:
      rect[2 + dim] = min(rect[2 + dim], min_size)
      rect[dim] += (space - rect[2 + dim]) / 2 - margins[wdim]
    elif align == LAY_RIGHT:
      rect[2 + dim] = min(rect[2 + dim], min_size)
      rect[dim] = space - rect[2 + dim] - margins[wdim]
    elif align == LAY_HFILL:
      rect[2 + dim] = min_size
    else:
      rect[2 + dim] = min(rect[2 + dim], min_size)
    rect[dim] += offset
    ctx.rects[item] = rect
    item = ctx.items[item].next_sibling

proc lay_arrange_wrapped_overlay_squeezed(ctx: var lay_context, item: lay_id, dim: int): lay_scalar =
  let wdim = dim + 2
  var offset = ctx.rects[item][dim]
  var need_size: lay_scalar = 0
  var child = ctx.items[item].first_child
  var start_child = child
  while child != LAY_INVALID_ID:
    if (ctx.items[child].flags and LAY_BREAK) != 0:
      lay_arrange_overlay_squeezed_range(ctx, dim, start_child, child, offset, need_size)
      offset += need_size
      start_child = child
      need_size = 0
    let child_size = ctx.rects[child][dim] + ctx.rects[child][2 + dim] + ctx.items[child].margins[wdim]
    need_size = max(need_size, child_size)
    child = ctx.items[child].next_sibling
  lay_arrange_overlay_squeezed_range(ctx, dim, start_child, LAY_INVALID_ID, offset, need_size)
  offset += need_size
  return offset

proc lay_arrange(ctx: var lay_context, item: lay_id, dim: int) =
  let flags = ctx.items[item].flags
  let model = flags and LAY_ITEM_BOX_MODEL_MASK
  if model == (LAY_COLUMN or LAY_WRAP):
    if dim != 0:
      lay_arrange_stacked(ctx, item, 1, true)
      let offset = lay_arrange_wrapped_overlay_squeezed(ctx, item, 0)
      ctx.rects[item][2 + 0] = offset - ctx.rects[item][0]
  elif model == (LAY_ROW or LAY_WRAP):
    if dim == 0:
      lay_arrange_stacked(ctx, item, 0, true)
    else:
      discard lay_arrange_wrapped_overlay_squeezed(ctx, item, 1)
  elif model == LAY_COLUMN or model == LAY_ROW:
    if (flags and 1) == uint32(dim):
      lay_arrange_stacked(ctx, item, dim, false)
    else:
      let rect = ctx.rects[item]
      lay_arrange_overlay_squeezed_range(ctx, dim, ctx.items[item].first_child, LAY_INVALID_ID, rect[dim], rect[2 + dim])
  else:
    lay_arrange_overlay(ctx, item, dim)

  var child = ctx.items[item].first_child
  while child != LAY_INVALID_ID:
    lay_arrange(ctx, child, dim)
    child = ctx.items[child].next_sibling
