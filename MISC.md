# Misc snippets

```go
update_positions :: proc(position: ^Positions) {
    for pos, idx in positions {
		row := idx > 0 ? idx / GridRows : 0
		col := idx - (row * GridCols)
		pos.x, pos.y = i32(col * CellWidth), i32(row * CellHeight)
	}
}

if raylib.IsKeyPressed(raylib.KeyboardKey.F) {
    if !raylib.IsWindowFullscreen() {
        monitor := raylib.GetCurrentMonitor()

        WindowWidth = raylib.GetMonitorWidth(monitor)
        WindowHeight = raylib.GetMonitorHeight(monitor)

        CellWidth :: WindowWidth / GridCols
        CellHeight :: WindowHeight / GridRows

        update_positions(positions)

        raylib.SetWindowSize(WindowWidth, WindowHeight)
        raylib.ToggleFullscreen()
    } else {
        raylib.SetWindowSize(WindowWidth, WindowHeight)
        raylib.ToggleFullscreen()
    }
}
```
