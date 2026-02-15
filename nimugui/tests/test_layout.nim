import ../src/nimugui/layout

proc test() =
  var ctx: lay_context
  init_lay_context(ctx)

  let root = lay_item(ctx)
  lay_set_size_xy(ctx, root, 100, 100)
  # Use LAY_START to make it start from the top
  lay_set_contain(ctx, root, LAY_COLUMN or LAY_START)

  let child1 = lay_item(ctx)
  lay_set_size_xy(ctx, child1, 50, 20)
  lay_set_behave(ctx, child1, LAY_HFILL)
  lay_insert(ctx, root, child1)

  let child2 = lay_item(ctx)
  lay_set_size_xy(ctx, child2, 50, 20)
  lay_set_behave(ctx, child2, LAY_HFILL)
  lay_insert(ctx, root, child2)

  lay_run_context(ctx)

  let r1 = lay_get_rect(ctx, child1)
  let r2 = lay_get_rect(ctx, child2)

  echo "Child 1: ", r1
  echo "Child 2: ", r2

  if r1[0] == 0 and r1[1] == 0 and r1[2] == 100 and r1[3] == 20 and
     r2[0] == 0 and r2[1] == 20 and r2[2] == 100 and r2[3] == 20:
    echo "Layout test passed!"
  else:
    echo "Layout test FAILED!"
    quit(1)

test()
