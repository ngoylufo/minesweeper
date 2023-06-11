package main

import "core:fmt"

import "core:c/libc"
import "core:math"
import "core:math/rand"

import "vendor:raylib"

// *********************************************************
// CONSTANTS
// *********************************************************

WindowWidth :: 400
WindowHeight :: 400

GridRows :: 10
GridCols :: 10

CellCount :: GridRows * GridCols
CellWidth :: WindowWidth / GridCols
CellHeight :: WindowHeight / GridRows

FontSizeNormal :: 20

TextGameWon: cstring : "You Win!"
TextGameOver: cstring : "Game Over!"
TextRestart: cstring : "Press 'R' to restart!"

Cells :: [CellCount]^Cell
Positions :: [CellCount]^Position

GameState :: enum {
	Playing,
	Won,
	Lost,
}

Cell :: struct {
	mine, flagged, revealed: bool,
	neighbors:               i8,
}

Position :: struct {
	x, y: i32,
}

is_valid_index :: proc(idx: int) -> bool {
	return 0 <= idx && idx < CellCount
}

// TODO: This can probably be simplified.
is_valid_neighbor :: proc(idx: int, ndx: int) -> bool {
	if ndx < 0 || idx == ndx || !is_valid_index(ndx) {
		return false
	}

	ri := idx > 0 ? idx / GridRows : 0
	rn := ndx > 0 ? ndx / GridRows : 0

	switch rn - ri {
	case 1:
		delta := idx + GridCols
		return delta - 1 == ndx || ndx == delta || ndx == delta + 1
	case -1:
		delta := idx - GridCols
		return delta - 1 == ndx || ndx == delta || ndx == delta + 1
	case 0:
		return ndx == idx - 1 || ndx == idx + 1
	}

	return false
}

make_position :: proc(x, y: i32) -> ^Position {
	pos := new(Position)
	pos.x, pos.y = x, y
	return pos
}

get_relative_offsets :: proc(idx: int) -> (cols: [3]int, rows: [3]int) {
	return [3]int{idx - GridCols, idx, idx + GridCols}, [3]int{-1, 0, 1}
}

includes :: proc(ae: $T/[dynamic]$E, e: E) -> bool {
	for value in ae {
		if e == value {
			return true
		}
	}
	return false
}

place_mines :: proc(cells: ^Cells, total, idx: int) {
	count, exceptions := total, neighbors(cells, idx)
	append(&exceptions, idx)

	for count > 0 {
		idx := rand.int_max(CellCount)

		if includes(exceptions, idx) {
			continue
		}

		if !cells[idx].mine {
			cells[idx].mine = true
			count -= 1
		}
	}

	for cell, idx in cells {
		cell.neighbors = count_neighbors(cells, idx)
	}
}

count_neighbors :: proc(cells: ^Cells, idx: int) -> i8 {
	cols, rows := get_relative_offsets(idx)
	count: i8 = 0

	for col in cols {
		for row in rows {
			if ndx := col + row; is_valid_neighbor(idx, ndx) {
				count += i8(cells[ndx].mine)
			}
		}
	}

	return count
}

// TODO: Maybe consider changing this to be [dynamic]i16?
neighbors :: proc(cells: ^Cells, idx: int) -> [dynamic]int {
	cols, rows := get_relative_offsets(idx)
	results := [dynamic]int{}

	for col in cols {
		for row in rows {
			if ndx := col + row; is_valid_neighbor(idx, ndx) {
				append(&results, ndx)
			}
		}
	}

	return results
}

cell_draw :: proc(cell: ^Cell, pos: ^Position) {
	if cell.flagged {
		raylib.DrawRectangle(pos.x, pos.y, CellWidth, CellHeight, raylib.LIGHTGRAY)
	} else if cell.revealed {
		color := cell.mine ? raylib.RED : raylib.GREEN
		raylib.DrawRectangle(pos.x, pos.y, CellWidth, CellHeight, color)

		if !cell.mine && cell.neighbors > 0 {
			text := raylib.TextFormat("%d", cell.neighbors)
			text_draw_centered(text, pos.x + CellWidth / 2, pos.y + CellHeight / 2)
		}
	}
}

cell_reveal :: proc(cells: ^Cells, idx: int) -> int {
	cell, count := cells[idx], 0

	if !cell.flagged && !cell.revealed {
		cell.revealed, count = true, count + 1

		if !cell.mine && cell.neighbors == 0 {
			cols, rows := get_relative_offsets(idx)

			for col in cols {
				for row in rows {
					if ndx := col + row; is_valid_neighbor(idx, ndx) {
						count += cell_reveal(cells, ndx)
					}
				}
			}
		}
	}

	return count
}

text_draw :: proc(
	text: cstring,
	x, y: libc.int,
	size: libc.int = FontSizeNormal,
	color := raylib.BLACK,
) {
	raylib.DrawText(text, x, y, size, color)
}

text_draw_centered :: proc(
	text: cstring,
	x, y: libc.int,
	size: libc.int = FontSizeNormal,
	color := raylib.BLACK,
) {
	width := raylib.MeasureText(text, size)
	text_draw(text, x - width / 2, y - size / 2, size, color)
}

init :: proc() -> (^Cells, ^Positions) {
	cells, positions := new(Cells), new(Positions)

	for idx in 0 ..< CellCount {
		row := idx > 0 ? idx / GridRows : 0
		col := idx - (row * GridCols)
		positions[idx] = make_position(i32(col * CellWidth), i32(row * CellHeight))
	}

	for idx in 0 ..< CellCount {
		cells[idx] = new(Cell)
	}

	return cells, positions
}

main :: proc() {
	raylib.InitWindow(WindowWidth, WindowHeight, "Minesweeper")

	cells, positions := init()
	mines_placed := false
	total_mines := int(0.15 * CellCount)

	required, revealed := CellCount - total_mines, 0
	flags := total_mines

	state: GameState = .Playing
	background := raylib.Fade(raylib.RAYWHITE, 0.8)

	// fmt.printf("i8=%d, i16=%d, i32=%d \n", size_of(i8), size_of(i16), size_of(i32))
	// fmt.printf("The size of a Cell is %d \n", size_of(Cell))

	for !raylib.WindowShouldClose() {
		if raylib.IsKeyPressed(raylib.KeyboardKey.R) {
			state = GameState.Playing
			cells, positions = init()
			mines_placed = false
			flags = total_mines
			revealed = 0
			fmt.println("\n==== Game Restarted ====\n")
		} else if state == .Playing {
			if raylib.IsMouseButtonPressed(raylib.MouseButton.LEFT) {
				mouse := raylib.GetMousePosition()
				x, y := int(mouse.x / CellWidth), int(mouse.y / CellHeight)
				idx := (y * GridRows) + x

				if !mines_placed {
					place_mines(cells, total_mines, idx)
					mines_placed = true
				}
				revealed += cell_reveal(cells, idx)
				if cells[idx].mine {
					state = GameState.Lost
				} else if revealed == (CellCount - total_mines + flags) {
					state = GameState.Won
				}
			} else if raylib.IsMouseButtonPressed(raylib.MouseButton.RIGHT) {
				mouse := raylib.GetMousePosition()
				x, y := int(mouse.x / CellWidth), int(mouse.y / CellHeight)
				cell := cells[(y * GridRows) + x]

				if cell.flagged {
					cell.flagged = false
					flags += 1
				} else if !cell.revealed && flags > 0 {
					cell.flagged = true
					flags -= 1
				}
			}
		}

		raylib.BeginDrawing()
		raylib.ClearBackground(raylib.RAYWHITE)

		for idx := 0; idx < len(cells); idx += 1 {
			pos, cell := positions[idx], cells[idx]

			cell_draw(cell, pos)
			raylib.DrawRectangleLines(pos.x, pos.y, CellWidth, CellHeight, raylib.BLACK)
		}

		if state == .Lost {
			raylib.DrawRectangle(0, 0, WindowWidth, WindowHeight, background)
			text_draw_centered(TextGameOver, WindowWidth / 2, WindowHeight / 2, 50, raylib.RED)
			text_draw_centered(
				TextRestart,
				WindowWidth / 2,
				i32(0.9 * WindowHeight),
				FontSizeNormal,
				raylib.RED,
			)
		} else if state == .Won {
			raylib.DrawRectangle(0, 0, WindowWidth, WindowHeight, background)
			text_draw_centered(TextGameWon, WindowWidth / 2, WindowHeight / 2, 50, raylib.BLUE)
			text_draw_centered(
				TextRestart,
				WindowWidth / 2,
				i32(0.9 * WindowHeight),
				FontSizeNormal,
				raylib.BLUE,
			)
		}

		raylib.EndDrawing()
	}

	raylib.CloseWindow()
}
