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
Game_State :: struct {
    camera:       rl.Camera2D,
    entities:     [dynamic]Entity,
    solid_tiles:  [dynamic]rl.Rectangle,
    spikes:       map[Entity_ID]Direction,
    debug_shapes: [dynamic]Debug_Shape
}

gs: Game_State

main :: proc() {
    rl.InitWindow(WINDOW_WIDTH, WINDOW_HEIGHT, "Odinvania")
    rl.SetTargetFPS(60)

    gs.camera = rl.Camera2D { zoom = ZOOM }
    player_id: Entity_ID

    // Set up our level
    {
	level_data, ok := os.read_entire_file("../data/simple_level.dat")
	assert(ok, "Failed to load level data")
	x, y: f32

	for v in level_data {
	    switch v {
	    case '\n':
		y += TILE_SIZE
		x = 0
		continue
	    case '#':
		append(&gs.solid_tiles, Rect{x,y, TILE_SIZE, TILE_SIZE})
	    case 'P':
		player_id = entity_create(
		    {x = x, y = y, width = 16, height = 38, move_speed = 280, jump_force = 650}
		)
	    case 'e':
		entity_create(
		    Entity{
			collider = Rect{x,y, TILE_SIZE, TILE_SIZE},
			move_speed = 50,
			flags = {.Debug_Draw},
			behaviors = {.Walk, .Flip_At_Wall, .Flip_At_Edge},
			debug_color = rl.RED,
		    }
		)
	    case '^':
		id := entity_create(
		    Entity {
			collider = Rect{x, y + SPIKE_DIFF, SPIKE_BREADTH, SPIKE_DEPTH},
			on_enter = spike_on_enter,
			flags = {.Kinematic, .Debug_Draw},
			debug_color = rl.YELLOW
		    }
		)
		gs.spikes[id] = .Up
	    case 'v':
		id := entity_create(
		    Entity{
			collider = Rect{x, y, SPIKE_BREADTH, SPIKE_DEPTH},
			on_enter = spike_on_enter,
			flags = {.Kinematic, .Debug_Draw},
			debug_color = rl.YELLOW
		    }
		)
		gs.spikes[id] = .Down
	    case '>':
		id := entity_create(
		    Entity{
			collider = Rect{x, y, SPIKE_DEPTH, SPIKE_BREADTH},
			on_enter = spike_on_enter,
			flags = {.Kinematic, .Debug_Draw},
			debug_color = rl.YELLOW
		    }
		)
		gs.spikes[id] = .Right
	    case '<':
		id := entity_create(
		    Entity{
			collider = Rect{x + SPIKE_DIFF, y, SPIKE_DEPTH, SPIKE_BREADTH},
			on_enter = spike_on_enter,
			flags = {.Kinematic, .Debug_Draw},
			debug_color = rl.YELLOW
		    }
		)
		gs.spikes[id] = .Left
	    }
	// move X to the next tile
	x += TILE_SIZE
	}
    }

    for !rl.WindowShouldClose() {

	// Input
	dt := rl.GetFrameTime()
	player := entity_get(player_id)

	input_x: f32
	if rl.IsKeyDown(.D) do input_x += 1
	if rl.IsKeyDown(.A) do input_x -= 1
	if rl.IsKeyDown(.SPACE) && .Grounded in player.flags{
	    player.vel.y = -player.jump_force
	    player.flags -= {.Grounded}
	}
    
	// Simulate
	player.vel.x = input_x * player.move_speed
	// [:] take the slice of our dynamic arrays
	physics_update(gs.entities[:], gs.solid_tiles[:], dt)
	behavior_update(gs.entities[:], gs.solid_tiles[:], dt)

	// Render
	rl.BeginDrawing()
	rl.BeginMode2D(gs.camera)
	rl.ClearBackground(BG_COLOR)

	// Debug Drawing
	for e in gs.entities {
	    if .Debug_Draw in e.flags {
		rl.DrawRectangleLinesEx(e.collider, 1, e.debug_color)
	    }
	}
	
	// Create the map
	for rect in gs.solid_tiles {
	    rl.DrawRectangleRec(rect, rl.WHITE)
	    rl.DrawRectangleLinesEx(rect, 1, rl.GRAY)
	}

	// Draw the player
	rl.DrawRectangleLinesEx(player.collider, 1, rl.GREEN)

	for s in gs.debug_shapes {
	    switch v in s {
	    case Debug_Line:
		rl.DrawLineEx(v.start, v.end, v.thickness, v.color)
	    case Debug_Rect:
		rl.DrawRectangleLinesEx(
		    {v.pos.x, v.pos.y, v.size.x, v.size.y},
		    v.thickness,
		    v.color,
		)
	    case Debug_Circle:
		rl.DrawCircleLinesV(v.pos, v.radius, v.color)
	    }
	}

	rl.DrawFPS(20, 20)

	rl.EndMode2D()
	defer rl.EndDrawing()
	clear(&gs.debug_shapes)
    }

}

