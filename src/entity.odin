package game

import "core:time"
import rl "vendor:raylib"

Entity :: struct {
    using collider: Rect,
    vel:	        Vec2,
    move_speed:         f32,
    jump_force:         f32,
    health:	        int,
    max_health:         int,
    on_hit_damage:      int,
    debug_color:        rl.Color,
    texture:            ^rl.Texture,
    current_anim_name:  string,
    current_anim_frame: int,
    animation_timer:    f32,
    animations:     map[string]Animation,
    entity_ids:     map[Entity_ID]time.Time,
    flags:          bit_set[Entity_Flags],
    behaviors:      bit_set[Entity_Behaviors],
    on_enter, on_stay, on_exit: proc(self_id, other_id: Entity_ID),
    
} 

// Distinct make sure two ints for the ID will never be the same
Entity_ID :: distinct int

Entity_Flags :: enum {
    Grounded,
    Left,
    Dead,
    Immortal,
    Kinematic,
    Debug_Draw,
}

Entity_Behaviors :: enum {
    Walk,
    Flip_At_Wall,
    Flip_At_Edge,
}

entity_create :: proc(entity: Entity) -> Entity_ID {
    for &e, i in gs.entities {
	if .Dead in e.flags {
	    e = entity
	    e.flags -= {.Dead}
	    return Entity_ID(i)
	}
    }

    index := len(gs.entities)
    append(&gs.entities, entity)

    return Entity_ID(index)
}

entity_get :: proc(id: Entity_ID) -> ^Entity {
    if int(id) >= len(gs.entities) { return nil }
    return &gs.entities[int(id)]
}

entity_update :: proc(entities: []Entity, dt: f32) {
    for &e in entities {
	if e.health == 0 && .Immortal not_in e.flags {
	    e.flags += {.Dead}
	}

	if len(e.animations) > 0 {
	    anim := e.animations[e.current_anim_name]

	    // Switch Frames
	    e.animation_timer -= dt
	    if e.animation_timer <= 0 {
		e.current_anim_frame += 1

		// Loop, TODO: Reverse, Stop
		if e.current_anim_frame > anim.end {
		    e.current_anim_frame = anim.start 
		}

		e.animation_timer = anim.time
	    }
	}
    }
}
