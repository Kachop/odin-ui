# Plan for UI lib development

## TODOs
> 1. Remove any unnecessary dynamic allocations.

## Model

> 1. Handle input. (Hover logic and clicking uses previous frames tree).
> 2. Build new control tree. Building from root control adding children and siblings.
> 3. Traverse the tree and do the layout, render controls.
