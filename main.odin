package main

import "core:c/libc"
import "core:fmt"
import "core:strings"
import "core:math/rand"

import "vendor:raylib"

WINDOW_WIDTH :: 400
WINDOW_HEIGHT :: 400
COLUMNS :: 10
ROWS :: 10

CELL_WIDTH :: WINDOW_WIDTH / COLUMNS
CELL_HEIGHT :: WINDOW_HEIGHT / ROWS
CELL_COUNT :: COLUMNS * ROWS

Grid :: [ROWS][COLUMNS]^Cell

Cell :: struct {
	neighbors: int,
	revealed:  bool,
	flagged:   bool,
	mine:      bool,
}

// Draws centered text
draw_text :: proc(text: cstring, x, y, size: libc.int, color: raylib.Color) {
	width := raylib.MeasureText(text, size)
	raylib.DrawText(text, x - width / 2, y - size / 2, size, color)
}

cell_draw :: proc(cell: ^Cell, x, y: i32) {
	if cell.revealed {
		color := cell.mine ? raylib.RED : raylib.GREEN
		raylib.DrawRectangle(x, y, CELL_WIDTH, CELL_HEIGHT, color)
		if !cell.mine && cell.neighbors > 0 {
			text := raylib.TextFormat("%d", cell.neighbors)
			draw_text(text, x + CELL_WIDTH / 2, y + CELL_HEIGHT / 2, 20, raylib.BLACK)
		}
	} else if cell.flagged {
		raylib.DrawRectangle(x, y, CELL_WIDTH, CELL_HEIGHT, raylib.LIGHTGRAY)
	}
}

is_validate_index :: proc(x, y: int) -> bool {
	return (x >= 0 && x < ROWS) && (y >= 0 && y < COLUMNS)
}

cell_count_neighbors :: proc(cells: Grid, x, y: int) -> (count: int) {
	for ny in -1 ..= 1 {
		for nx in -1 ..= 1 {
			if nx == 0 && ny == 0 {
				continue
			}
			if is_validate_index(x + nx, y + ny) {
				count += int(cells[x + nx][y + ny].mine)
			}
		}
	}
	return count
}

init :: proc() -> ^Grid {
	cells := new(Grid)

	for y in 0 ..< ROWS {
		for x in 0 ..< COLUMNS {
			cells[x][y] = new(Cell)
		}
	}

	return cells
}

plant_mines :: proc(cells: ^Grid, mines, cx, cy: int) -> bool {
	mines := mines
	for mines > 0 {
		x := rand.int_max(ROWS)
		y := rand.int_max(COLUMNS)

		if cx == x && cy == y {
			continue
		}

		if !cells[x][y].mine {
			cells[x][y].mine = true
			mines -= 1
		}
	}

	for y in 0 ..< ROWS {
		for x in 0 ..< COLUMNS {
			cells[x][y].neighbors = cell_count_neighbors(cells^, x, y)
		}
	}

	return true
}

cell_reveal :: proc(cells: ^[ROWS][COLUMNS]^Cell, cell: ^Cell, x, y: int) -> int {
	count := 0
	if cell.revealed == false {
		cell.revealed = true
		count += 1

		if !cell.mine && cell.neighbors == 0 {
			for ny in -1 ..= 1 {
				for nx in -1 ..= 1 {
					if nx == 0 && ny == 0 {
						continue
					}
					if is_validate_index(x + nx, y + ny) &&
					   !cells[x + nx][y + ny].mine &&
					   !cells[x + nx][y + ny].flagged {
						count += cell_reveal(cells, cells[x + nx][y + ny], x + nx, y + ny)
					}
				}
			}
		}
	}
	return count
}

cell_flag :: proc(cell: ^Cell, mines: ^int) {
	if cell.flagged {
		cell.flagged = false
		mines^ += 1
	} else if !cell.revealed && mines^ > 0 {
		cell.flagged = true
		mines^ -= 1
	}
}

main :: proc() {
	raylib.InitWindow(WINDOW_WIDTH, WINDOW_HEIGHT, "Minesweeper")

	mines_total := int(0.15 * ROWS * COLUMNS)
	mines := mines_total
	mines_planted := false
	game_over := false
	game_won := false
	revealed := 0

	cells := init()

	for !raylib.WindowShouldClose() {
		if raylib.IsKeyPressed(raylib.KeyboardKey.R) {
			mines_planted = false
			game_over = false
			game_won = false
			revealed = 0
			mines = mines_total
			cells = init()
		} else if !game_over {
			if raylib.IsMouseButtonPressed(raylib.MouseButton.LEFT) {
				mouse := raylib.GetMousePosition()
				x := int(mouse.x / CELL_WIDTH)
				y := int(mouse.y / CELL_HEIGHT)

				if !mines_planted {
					mines_planted = plant_mines(cells, mines, x, y)
				}

				if !cells[x][y].flagged {
					revealed += cell_reveal(cells, cells[x][y], x, y)
					fmt.printf("revealed %d\n", revealed)
				}

				if revealed == (ROWS * COLUMNS - mines_total + mines) {
					game_won = true
				}

				fmt.printf("required %d\n", ROWS * COLUMNS - mines_total)
			} else if raylib.IsMouseButtonPressed(raylib.MouseButton.RIGHT) {
				mouse := raylib.GetMousePosition()
				x := int(mouse.x / CELL_WIDTH)
				y := int(mouse.y / CELL_HEIGHT)

				cell_flag(cells[x][y], &mines)
				fmt.printf("mines %d\n", mines)
			}
		}

		raylib.BeginDrawing()
		raylib.ClearBackground(raylib.RAYWHITE)

		for i in 0 ..< ROWS {
			for j in 0 ..< COLUMNS {
				x := i32(i * CELL_WIDTH)
				y := i32(j * CELL_HEIGHT)

				if cells[i][j].revealed && cells[i][j].mine {
					game_over = true
				}

				cell_draw(cells[i][j], x, y)
				raylib.DrawRectangleLines(x, y, CELL_WIDTH, CELL_HEIGHT, raylib.BLACK)
			}
		}

		if game_over {
			draw_text("Game Over", WINDOW_WIDTH / 2, WINDOW_HEIGHT / 2, 50, raylib.RED)
		} else if game_won {
			draw_text("You Win", WINDOW_WIDTH / 2, WINDOW_HEIGHT / 2, 50, raylib.BLUE)
		}

		raylib.EndDrawing()
	}

	raylib.CloseWindow()
}
