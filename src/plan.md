# Plan for UI lib development

## TODOs
> 1. Remove any unnecessary dynamic allocations.
> 2. If layout overspills and all of the elements have already been reduced to their minumum then proportionally reduce everything.

Issues with overspills. If .Grow_To_Parent element present with no space to go things get wacky.

Ideal process for fixing overspills:

> 1. Reduce the size of all flexible containers to their minimum.
> 2. Calculate the remaining overspill.
> 3. Reduce everything available so it all fits onto the screen.

## Model

> 1. Handle input. (Hover logic and clicking uses previous frames tree).
> 2. Build new control tree. Building from root control adding children and siblings.
> 3. Traverse the tree and do the layout, render controls.
