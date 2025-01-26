package game

import "core:fmt"
import "core:os"
import rl "vendor:raylib"

// Constants
WINDOW_WIDTH   :: 1280
WINDOW_HEIGHT  :: 720
ZOOM           :: 2
BG_COLOR       :: rl.BLACK
TILE_SIZE      :: 16

// Type Aliases
Vec2 :: rl.Vector2
Rect :: rl.Rectangle

// Types
Player :: struct {
    using collider: Rect,
    vel:	    Vec2,
    move_speed:     f32,
}


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

    // Initialize our player
    player := Player{ x = 100, y = 100, width = 16, height = 38, move_speed = 280}

    for !rl.WindowShouldClose() {

	// Input
	dt := rl.GetFrameTime()

	input_x: f32
	if rl.IsKeyDown(.D) do input_x += 1
	if rl.IsKeyDown(.A) do input_x -= 1

	// Simulate
	player.vel.x = input_x * player.move_speed
	player.x += player.vel.x * dt

	// Render
	rl.BeginDrawing()
	rl.BeginMode2D(camera)
	rl.ClearBackground(BG_COLOR)

	for rect in solid_tiles {
	    rl.DrawRectangleRec(rect, rl.WHITE)
	    rl.DrawRectangleLinesEx(rect, 1, rl.GRAY)
	}

	rl.DrawRectangleLinesEx(player.collider, 1, rl.GREEN)

	defer rl.EndMode2D()
	defer rl.EndDrawing()
    }

}
