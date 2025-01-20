package game

import "core:fmt"
import rl "vendor:raylib"

WINDOW_WIDTH   :: 1280
WINDOW_HEIGHT :: 720
ZOOM          :: 2
BG_COLOR      :: rl.BLACK

main :: proc() {
    rl.InitWindow(WINDOW_WIDTH, WINDOW_HEIGHT, "Odinvania")

    camera := rl.Camera2D { zoom = ZOOM }

    for !rl.WindowShouldClose() {
	rl.BeginDrawing()
	rl.BeginMode2D(camera)
	rl.ClearBackground(BG_COLOR)

	defer rl.EndMode2D()
	defer rl.EndDrawing()
    }

}
