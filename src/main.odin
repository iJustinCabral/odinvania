package game

import "core:fmt"
import "core:os"
import "core:time"
import "core:slice"
import "base:intrinsics"
import "core:encoding/json"
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
    colliders:             [dynamic]Rect,
    wide_rects:            [dynamic]Rect,
    solid_tiles:           [dynamic]rl.Rectangle,
    spikes:                map[Entity_ID]Direction,
    debug_shapes:          [dynamic]Debug_Shape
}

Animation :: struct {
    size:         Vec2, // anim frame size 
    offset:       Vec2, // Line things up with collider
    start:        int, // Start column (0 index)
    end:          int, // Ending column (0 index)
    row:          int, // Row (0 index)
    time:         f32, // How long each frame takes 
    flags:        bit_set[Animation_Flags],
    on_finish:    proc(gs: ^Game_State, entity: ^Entity),
    timed_events: [dynamic]Animation_Event
}

Animation_Flags :: enum {
    Loop,
    Ping_Pong, // Loop + Ping_Pong will play forwards, backwards, forwards
}

Animation_Event :: struct {
    timer:    f32,
    duration: f32,
    callback: proc(gs: ^Game_State, entity: ^Entity)
}

LDtk_Data :: struct {
    levels: []LDtk_Level,
}

LDtk_Level :: struct {
    identifier: string,
    layerInstances: []LDtk_Layer_Instance,
}

LDtk_Layer_Instance :: struct {
    __identifier:    string,
    __tyep:          string,
    __cWid, __cHei:  int,
    intGridCsv:      []int,
    autoLayerTiles:  []LDtk_Auto_Layer_Tile,
    entityInstances: []LDtk_Entity,
}

LDtk_Auto_Layer_Tile :: struct {
    px: [2]f32,
}

LDtk_Entity :: struct {
    __identifier: string,
    __worldX:     f32,
    __worldY:     f32,
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
	time = 0.15,
	flags = {.Loop}
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
	flags = {.Loop}
    }

    player_anim_run := Animation {
	size = {120, 80},
	offset = {52, 42},
	start = 0,
	end = 9,
	row = 2,
	time = 0.15,
	flags = {.Loop}
    }

    player_anim_attack := Animation {
	size = {120, 80},
	offset = {52, 42},
	start = 0,
	end = 3,
	row = 3,
	time = 0.15,
	on_finish = player_on_finish_attack,
	timed_events = {{timer = 0.15, duration = 0.15, callback = player_attack_callback}},
    }


    // Set up our level
    {
	level_data, ok := os.read_entire_file("../data/world.ldtk", allocator = context.allocator)
	assert(ok, "Failed to load level data")
	x, y: f32
	
	ldtk_data:= new(LDtk_Data, context.temp_allocator)
	err := json.unmarshal(level_data, ldtk_data, allocator = context.allocator)

	if err != nil {
	    fmt.println(err)
	    return
	}

	for level in ldtk_data.levels {
	    if level.identifier != "Level_0" do continue

	    for layer in level.layerInstances {
		switch layer.__identifier {
		case "Entities":
		    for entity in layer.entityInstances {
			switch entity.__identifier {
			case "Player":
			    px, py := entity.__worldX, entity.__worldY
			    gs.player_id = entity_create(
				{
				    x = px,
				    y = py,
				    width = 16,
				    height = 38,
				    move_speed = 280,
				    jump_force = 650,
				    health = 5,
				    max_health = 5,
				    debug_color = rl.GREEN,
				    texture = &player_texture,
				    on_enter = player_on_enter,
				    current_anim_name = "idle",
				    animations = {
					"idle" = player_anim_idle,
					"jump" = player_anim_jump,
					"jump_fall_inbetween" = player_anim_jump_fall_inbetween,
					"fall" = player_anim_fall,
					"run"  = player_anim_run,
					"attack" = player_anim_attack,
				    },

				},
			    )
			case "Door":
			}
		    }
		case "Collisions":
		    x, y: f32
		    for v, i in layer.intGridCsv {
			if v != 0 {
			    append(&gs.solid_tiles, Rect{x,y, TILE_SIZE, TILE_SIZE})
			}

			x += TILE_SIZE
			if (i + 1) % layer.__cWid == 0 { // when we hit the edge of level, move down y and reset x
			    y += TILE_SIZE
			    x = 0
			}
		    }

		    // Joining adjacent tiles on the x axis into one wide tile
		    wide_rect := gs.solid_tiles[0]

		    for i in 1..<len(gs.solid_tiles) {
			rect := gs.solid_tiles[i]

			if rect.x == wide_rect.x + wide_rect.width {
			    wide_rect.width += TILE_SIZE
			}
			else {
			    append(&gs.wide_rects, wide_rect)
			    wide_rect = rect
			}
		    }

		    append(&gs.wide_rects, wide_rect)

		    slice.sort_by(gs.wide_rects[:], proc(a,b: Rect) -> bool {
			if a.x != b.x do return a.x < b.x
			return a.y < b.y
		    })

		    // Joining adjacent tiles on the y axis into one big rect
		    big_rect := gs.wide_rects[0]

		    for i in 1..<len(gs.wide_rects) {
			rect := gs.wide_rects[i]

			if rect.x == big_rect.x && rect.width == big_rect.width && big_rect.y + big_rect.height == rect.y {
			    big_rect.height += TILE_SIZE 
			} 
			else {
			    append(&gs.colliders, big_rect)
			    big_rect = rect 
			}
		    }

		    append(&gs.colliders, big_rect)

		}
	    }
	}
	
    }

    for !rl.WindowShouldClose() {

	// Input
	dt := rl.GetFrameTime()
	player := entity_get(gs.player_id)

	// [:] take the slice of our dynamic arrays
	player_update(&gs, dt)
	entity_update(&gs, dt)
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
	
	// Draw collision tiles
	for rect in gs.colliders {
	    rl.DrawRectangleLinesEx(rect, 1, rl.ORANGE)
	}

	for rect in gs.solid_tiles {
	    rl.DrawRectangleLinesEx(rect,1, {255, 255, 255, 40})
	}

	// Attack circle
	debug_draw_circle(
	    {player.collider.x, player.collider.y} +
	    {.Left in player.flags ? -30 + player.collider.width : 30, 20},
	    25,
	    rl.GREEN,

	)

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

