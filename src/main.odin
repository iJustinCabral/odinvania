package game

import "core:fmt"
import "core:os"
import rl "vendor:raylib"

WINDOW_WIDTH   :: 1280
WINDOW_HEIGHT  :: 720
ZOOM           :: 2
BG_COLOR       :: rl.BLACK
TILE_SIZE      :: 16

main :: proc() {
    rl.InitWindow(WINDOW_WIDTH, WINDOW_HEIGHT, "Odinvania")

    camera := rl.Camera2D { zoom = ZOOM }
    solid_tiles: [dynamic]rl.Rectangle

    // Set up our level
    {
	data, ok := os.read_entire_file("../data/simple_level.dat")
	assert(ok, "Failed to load level data")
	x, y: f32

	for v in data {
	    if v == '\n' {
		y += TILE_SIZE
		x = 0
		continue
	    }
	    if v == '#' {
		append(&solid_tiles, rl.Rectangle{x, y, TILE_SIZE, TILE_SIZE})
	    }
	    x += TILE_SIZE
	}
    }

    for !rl.WindowShouldClose() {
	rl.BeginDrawing()
	rl.BeginMode2D(camera)
	rl.ClearBackground(BG_COLOR)

	for rect in solid_tiles {
	    rl.DrawRectangleRec(rect, rl.WHITE)
	    rl.DrawRectangleLinesEx(rect, 1, rl.GRAY)
	}

	defer rl.EndMode2D()
	defer rl.EndDrawing()
    }

}
