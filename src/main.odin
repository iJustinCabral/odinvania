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
UP             :: Vec2{0, -1}
RIGHT          :: Vec2{1, 0}
DOWN           :: Vec2{0, 1}
LEFT           :: Vec2{-1, 0}
PLAYER_SAFE_RESET_TIME :: 1

// Type Aliases	    
Vec2 :: rl.Vector2
Rect :: rl.Rectangle

// Types
Game_State :: struct {
    camera:                rl.Camera2D,
    player_id:             Entity_ID,
    safe_position:         Vec2,
    safe_reset_timer:      f32,
    player_movement_state: Player_Movement_State,
    entities:              [dynamic]Entity,
    solid_tiles:           [dynamic]rl.Rectangle,
    spikes:                map[Entity_ID]Direction,
    debug_shapes:          [dynamic]Debug_Shape
}

Animation :: struct {
    size:   Vec2, // anim frame size 
    offset: Vec2, // Line things up with collider
    start:  int, // Start column (0 index)
    end:    int, // Ending column (0 index)
    row:    int, // Row (0 index)
    time:   f32, // How long each frame takes 
}

gs: Game_State

main :: proc() {
    rl.InitWindow(WINDOW_WIDTH, WINDOW_HEIGHT, "Odinvania")
    rl.SetTargetFPS(60)

    gs.camera = rl.Camera2D { zoom = ZOOM }

    player_texture := rl.LoadTexture("../assets/textures/player_sheet.png")
    
    player_anim_idle := Animation {
	size = {120, 80},
	offset = {52, 42},
	start = 0,
	end = 9,
	row = 0,
	time = 0.15
    }

    player_anim_jump := Animation {
	size = {120, 80},
	offset = {52, 42},
	start = 0,
	end = 2,
	row = 1,
	time = 0.15,
    }

    player_anim_jump_fall_inbetween := Animation {
	size = {120, 80},
	offset = {52, 42},
        start = 3,
	end = 4,
	row = 1,
	time = 0.15,
    }

    player_anim_fall := Animation {
	size = {120, 80},
	offset = {52, 42},
	start = 5,
	end = 7,
	row = 1,
	time = 0.15,
    }

    player_anim_run := Animation {
	size = {120, 80},
	offset = {52, 42},
	start = 0,
	end = 9,
	row = 2,
	time = 0.15,
    }


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
		gs.player_id = entity_create(
		    {
			x = x, y = y, width = 16, height = 38, move_speed = 280, jump_force = 650,
			on_enter = player_on_enter,
			health = 5,
			max_health = 5,
			texture = &player_texture,
			animations = {
			    "idle" = player_anim_idle,
			    "jump" = player_anim_jump,
			    "jump_fall_inbetween" = player_anim_jump_fall_inbetween,
			    "fall" = player_anim_fall,
			    "run" = player_anim_run,
			},
			current_anim_name = "idle",
		    }
		)
	    case 'e':
		entity_create(
		    Entity{
			collider = Rect{x,y, TILE_SIZE, TILE_SIZE},
			move_speed = 50,
			flags = {.Debug_Draw},
			behaviors = {.Walk, .Flip_At_Wall, .Flip_At_Edge},
			debug_color = rl.RED,
			health = 2,
			max_health = 2,
			on_hit_damage = 1,
		    }
		)
	    case '^':
		id := entity_create(
		    Entity {
			collider = Rect{x, y + SPIKE_DIFF, SPIKE_BREADTH, SPIKE_DEPTH},
			on_enter = spike_on_enter,
			flags = {.Kinematic, .Immortal, .Debug_Draw},
			debug_color = rl.YELLOW,
			on_hit_damage = 1
		    }
		)
		gs.spikes[id] = .Up
	    case 'v':
		id := entity_create(
		    Entity{
			collider = Rect{x, y, SPIKE_BREADTH, SPIKE_DEPTH},
			on_enter = spike_on_enter,
			flags = {.Kinematic, .Immortal, .Debug_Draw},
			debug_color = rl.YELLOW,
			on_hit_damage = 1,
		    }
		)
		gs.spikes[id] = .Down
	    case '>':
		id := entity_create(
		    Entity{
			collider = Rect{x, y, SPIKE_DEPTH, SPIKE_BREADTH},
			on_enter = spike_on_enter,
			flags = {.Kinematic, .Immortal, .Debug_Draw},
			debug_color = rl.YELLOW,
			on_hit_damage = 1,
		    }
		)
		gs.spikes[id] = .Right
	    case '<':
		id := entity_create(
		    Entity{
			collider = Rect{x + SPIKE_DIFF, y, SPIKE_DEPTH, SPIKE_BREADTH},
			on_enter = spike_on_enter,
			flags = {.Kinematic, .Immortal, .Debug_Draw},
			debug_color = rl.YELLOW,
			on_hit_damage = 1,
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
	player := entity_get(gs.player_id)

	// [:] take the slice of our dynamic arrays
	player_update(&gs, dt)
	entity_update(gs.entities[:], dt)
	physics_update(gs.entities[:], gs.solid_tiles[:], dt)
	behavior_update(gs.entities[:], gs.solid_tiles[:], dt)

	if .Grounded in player.flags {
	    pos := Vec2{player.x, player.y}
	    size := Vec2{player.width, player.height}

	    targets := make([dynamic]Rect, context.temp_allocator)
	    for e, i in gs.entities {
		if Entity_ID(i) == gs.player_id do continue
		if .Dead not_in e.flags {
		    append(&targets, e.collider)
		}
	    }

	    safety_check: {
		_, hit_ground_left := raycast(pos + {0, size.y}, DOWN * 2, gs.solid_tiles[:])
		if !hit_ground_left do break safety_check

		_, hit_ground_right := raycast(pos + size, DOWN * 2, gs.solid_tiles[:])
		if !hit_ground_right do break safety_check

		_, hit_entity_left := raycast(pos, LEFT * TILE_SIZE, targets[:])
		if hit_entity_left do break safety_check

		_, hit_entity_right := raycast(pos + {size.x, 0}, RIGHT * TILE_SIZE, targets[:])
		if hit_entity_right do break safety_check

		gs.safe_position = pos
	    }
	}

	// Render
	rl.BeginDrawing()
	rl.BeginMode2D(gs.camera)
	rl.ClearBackground(BG_COLOR)

	// Debug Drawing
	for &e in gs.entities {
	    if e.texture != nil {
		e.animation_timer -= dt

		anim := e.animations[e.current_anim_name]

		// Rectangle on texture (sprite sheet)
		source := Rect {
		    f32(e.current_anim_frame) * anim.size.x,
		    f32(anim.row) * anim.size.y,
		    anim.size.x,
		    anim.size.y
		}

		if .Left in e.flags {
		    source.width = -source.width // Flips the sprite when going left
		}

		rl.DrawTextureRec(e.texture^, source, {e.x, e.y} - anim.offset, rl.WHITE)
	    }

	    if .Debug_Draw in e.flags && .Dead not_in e.flags {
		rl.DrawRectangleLinesEx(e.collider, 1, e.debug_color)
	    }
	}
	
	// Create the map
	for rect in gs.solid_tiles {
	    rl.DrawRectangleRec(rect, rl.WHITE)
	    rl.DrawRectangleLinesEx(rect, 1, rl.GRAY)
	}

	// Draw the player
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

