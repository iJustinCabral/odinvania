package game

import "core:fmt"
import "core:log"
import "core:os"
import "core:time"
import "core:slice"
import "base:intrinsics"
import "core:encoding/json"
import rl "vendor:raylib"

// Constants
WINDOW_WIDTH   :: 1280
WINDOW_HEIGHT  :: 720
RENDER_WIDTH   :: 640
RENDER_HEIGHT  :: 360
ZOOM           :: WINDOW_WIDTH / RENDER_WIDTH
BG_COLOR       :: rl.BLACK
TILE_SIZE      :: 16
JUMP_TIME      :: 0.2
COYOTE_TIME    :: 0.15
UP             :: Vec2{0, -1}
RIGHT          :: Vec2{1, 0}
DOWN           :: Vec2{0, 1}
LEFT           :: Vec2{-1, 0}
PLAYER_SAFE_RESET_TIME :: 1
ATTACK_COOLDOWN :: 0.3
ATTACK_RECOVERY :: 0.2

// Type Aliases	    
Vec2 :: rl.Vector2
Rect :: rl.Rectangle

// Types
Game_State :: struct {
    camera:                rl.Camera2D,
    player_id:             Entity_ID,
    safe_position:         Vec2,
    safe_reset_timer:      f32,
    level_min:             Vec2, // tope left of level
    level_max:             Vec2, // bottom right of level
    jump_timer:            f32,
    coyote_timer:          f32,
    attack_cooldown_timer: f32,
    attack_recovery_timer: f32,
    player_movement_state: Player_Movement_State,
    entities:              [dynamic]Entity,
    colliders:             [dynamic]Rect,
    bg_tiles:              [dynamic]Tile,
    tiles:                 [dynamic]Tile,
    spikes:                map[Entity_ID]Direction,
    enemty_defintions:     map[string]Enemy_Def,
    debug_shapes:          [dynamic]Debug_Shape,
    debug_draw_enabled:    bool,
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
    worldX: f32,
    worldY: f32,
    pxWid: f32,
    pxHei: f32,
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
    px:  [2]f32, // position on the world map
    src: Vec2, // where the tile is in the tileset
    f:   u8, // is it flipped
}

LDtk_Entity :: struct {
    __identifier:   string,
    __worldX:       f32,
    __worldY:       f32,
    __tags:         []string,
    width:          f32,
    height:         f32,
    fieldInstances: []LDtk_Field_Instance,
}

LDtk_Field_Instance :: struct {
    __identifier: string,
    __type:       string,
    __value:      LDtk_Field_Instance_Value,
}

LDtk_Field_Instance_Value :: union {
    LDtk_Entity_Ref,
    bool,
    f32,
    int,
}

LDtk_Entity_Ref :: struct {
    entityIid: string,
    layerIid:  string,
    levelIid:  string,
    worldIid:  string,
}

Tile :: struct {
    pos: Vec2,
    src: Vec2,
    f:   u8,
}

Enemy_Def :: struct {
    collider_size:       Vec2,
    move_speed:          f32,
    behaviors:           bit_set[Entity_Behaviors],
    health:              int,
    on_hit_damage:       int,
    texture:             rl.Texture2D,
    animations:          map[string]Animation,
    initial_animation:   string,
    hit_response:        Entity_Hit_Response,
    hit_duration:        f32,
    hit_knockback_force: f32,
}

gs: Game_State

main :: proc() {
    rl.InitWindow(WINDOW_WIDTH, WINDOW_HEIGHT, "Odinvania")
    rl.SetTargetFPS(60)
    
    gs.camera = rl.Camera2D {
	zoom = ZOOM,
    } 

    player_texture := rl.LoadTexture("../assets/textures/player_sheet.png")
    tileset_texure := rl.LoadTexture("../assets/textures/tileset.png")

    gs.enemty_defintions["Walker"] = Enemy_Def {
	collider_size = {36, 18},
	move_speed = 35,
	health = 3,
	behaviors = {.Walk, .Flip_At_Wall, .Flip_At_Edge},
	on_hit_damage = 1,
	texture = rl.LoadTexture("../assets/textures/opossum_36x28.png"),
	animations = {
	    "walk" = Animation {
		size = {36, 28},
		offset = {0, 10},
		start = 0,
		end = 5,
		time = 0.15,
		flags = {.Loop},
	    },
	},
	initial_animation = "walk",
	hit_response = .Stop,
	hit_duration = 0.25,
    }
    
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
	time = 0.05,
	on_finish = player_on_finish_attack,
	timed_events = {{timer = 0.05, duration = 0.05, callback = player_attack_callback}},
    }


    // Set up our level
    {
	level_data, ok := os.read_entire_file("../data/world.ldtk", allocator = context.allocator)
	assert(ok, "Failed to load level data")
	x, y: f32
	
	ldtk_data:= new(LDtk_Data, context.temp_allocator)
	err := json.unmarshal(level_data, ldtk_data, allocator = context.allocator)

	if err != nil {
	    log.panicf("failed to parse level json data: %v", err)    
	}

	for level in ldtk_data.levels {
	    if level.identifier != "Level_0" do continue

	    gs.level_min = {level.worldX, level.worldY}
	    gs.level_max = gs.level_min + {level.pxWid, level.pxHei}

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

			if slice.contains(entity.__tags, "Enemy") {
			    def := &gs.enemty_defintions[entity.__identifier]

			    enemy := Entity {
				collider = {
				    entity.__worldX,
				    entity.__worldY,
				    def.collider_size.x,
				    def.collider_size.y,
				},
				move_speed = def.move_speed,
				behaviors  = def.behaviors,
				health     = def.health,
				on_hit_damage = def.on_hit_damage,
				texture = &def.texture,
				animations = def.animations,
				current_anim_name = def.initial_animation,
				debug_color = rl.RED,
				flags = {.Debug_Draw},
				hit_response = def.hit_response,
				hit_duration = def.hit_duration,
			    }

			    entity_create(enemy)
			}
		    }
		case "Collisions":
		    solid_tiles := make([dynamic]Rect, context.temp_allocator)

		    x, y: f32
		    for v, i in layer.intGridCsv {
			if v != 0 {
			    append(&solid_tiles, Rect{x,y, TILE_SIZE, TILE_SIZE})
			}

			x += TILE_SIZE
			if (i + 1) % layer.__cWid == 0 { // when we hit the edge of level, move down y and reset x
			    y += TILE_SIZE
			    x = 0
			}
		    }

		    // Joining adjacent tiles on the x axis into one wide tile
		    wide_rect := solid_tiles[0]
		    wide_rects := make([dynamic]Rect, context.temp_allocator)

		    for i in 1..<len(solid_tiles) {
			rect := solid_tiles[i]

			if rect.x == wide_rect.x + wide_rect.width {
			    wide_rect.width += TILE_SIZE
			}
			else {
			    append(&wide_rects, wide_rect)
			    wide_rect = rect
			}
		    }

		    append(&wide_rects, wide_rect)

		    slice.sort_by(wide_rects[:], proc(a,b: Rect) -> bool {
			if a.x != b.x do return a.x < b.x
			return a.y < b.y
		    })

		    // Joining adjacent tiles on the y axis into one big rect
		    big_rect := wide_rects[0]

		    for i in 1..<len(wide_rects) {
			rect := wide_rects[i]

			if rect.x == big_rect.x && rect.width == big_rect.width && big_rect.y + big_rect.height == rect.y {
			    big_rect.height += TILE_SIZE 
			} 
			else {
			    append(&gs.colliders, big_rect)
			    big_rect = rect 
			}
		    }

		    append(&gs.colliders, big_rect)

		    // LDtk Tiles
		    for auto_tile in layer.autoLayerTiles {
			append(&gs.tiles, Tile{auto_tile.px, auto_tile.src, auto_tile.f})
		    }
		
		case "Background":
		    for auto_tile in layer.autoLayerTiles {
			append(&gs.bg_tiles, Tile{auto_tile.px, auto_tile.src, auto_tile.f})
		    }

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
	physics_update(gs.entities[:], gs.colliders[:], dt)
	behavior_update(gs.entities[:], gs.colliders[:], dt)

	// Camera Update 
	{
	    // Camera target starts in the top left, so we want it to be on our player in the center of the screen
	    render_half_size := Vec2{RENDER_WIDTH, RENDER_HEIGHT} / 2
	    gs.camera.target = {player.x, player.y} - render_half_size

	    if gs.camera.target.x < gs.level_min.x {
		gs.camera.target.x = gs.level_min.x 
	    }

	    if gs.camera.target.y < gs.level_min.y {
		gs.camera.target.y = gs.level_min.y 
	    }

	    if gs.camera.target.x + RENDER_WIDTH > gs.level_max.x {
		gs.camera.target.x = gs.level_max.x - RENDER_WIDTH
	    }

	    if gs.camera.target.y + RENDER_HEIGHT > gs.level_max.y {
		gs.camera.target.y = gs.level_max.y - RENDER_HEIGHT
	    }
	}

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
		_, hit_ground_left := raycast(pos + {0, size.y}, DOWN * 2, gs.colliders[:])
		if !hit_ground_left do break safety_check

		_, hit_ground_right := raycast(pos + size, DOWN * 2, gs.colliders[:])
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

	// Draw the LDtk background tiles
	for tile in gs.bg_tiles {
	    width: f32 = TILE_SIZE
	    height: f32 = TILE_SIZE

	    if tile.f == 1 || tile.f == 3 {
		width = -TILE_SIZE
	    }
	    else if tile.f == 2 || tile.f == 3 {
		height = -TILE_SIZE
	    }

	    rl.DrawTextureRec(
		tileset_texure,
		{tile.src.x, tile.src.y, width, height},
		tile.pos,
		rl.WHITE,
	    )
	}

	// Draw the LDtk foreground tiles
	for tile in gs.tiles {
	    width: f32 = TILE_SIZE
	    height: f32 = TILE_SIZE

	    if tile.f == 1 || tile.f == 3 {
		width = -TILE_SIZE
	    }
	    else if tile.f == 2 || tile.f == 3 {
		height = -TILE_SIZE
	    }

	    rl.DrawTextureRec(
		tileset_texure,
		{tile.src.x, tile.src.y, width, height},
		tile.pos,
		rl.WHITE,
	    )
	}

	// Debug Drawing
	for &e in gs.entities {
	    if .Dead in e.flags do continue 

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
	    
	    if gs.debug_draw_enabled {
		if .Debug_Draw in e.flags && .Dead not_in e.flags {
		    rl.DrawRectangleLinesEx(e.collider, 1, e.debug_color)
		}
	    }
	}
	
	// Draw collision tiles
	for rect in gs.colliders {
	    rl.DrawRectangleLinesEx(rect, 1, rl.ORANGE)
	}

	for rect in gs.colliders {
	    rl.DrawRectangleRec(rect, {255, 255, 255, 40})
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


	rl.EndMode2D()
	rl.DrawFPS(20, 20)
	defer rl.EndDrawing()
	clear(&gs.debug_shapes)
    }

}

