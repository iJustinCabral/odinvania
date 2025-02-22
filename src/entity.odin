package game

import "core:time"
import "core:fmt"
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
    hit_timer:          f32,
    hit_duration:       f32,
    hit_response:       Entity_Hit_Response,
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
    Frozen,
    Kinematic,
    Debug_Draw,
}

Entity_Behaviors :: enum {
    Walk,
    Flip_At_Wall,
    Flip_At_Edge,
}

Entity_Hit_Response :: enum {
    Stop,
    Knockback,
}

switch_animation :: proc(entity: ^Entity, name: string) {
    entity.current_anim_name = name 
    anim := &entity.animations[name] // Pointer to reset event timers
    entity.animation_timer = anim.time
    entity.current_anim_frame = anim.start

    for &event in anim.timed_events {
	event.timer = event.duration
    }
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

entity_damage :: proc(id: Entity_ID, amount: int) {
    entity := entity_get(id)
    entity.health -= amount

    if entity.health <= 0 {
	entity.flags += {.Dead}
    }
}

entity_hit :: proc(id: Entity_ID, hit_force:= Vec2{}) {
    entity := entity_get(id)
    entity.hit_timer = entity.hit_duration

    switch entity.hit_response {
    case .Stop:
	entity.behaviors -= {.Walk}
	entity.flags += {.Frozen}
	entity.vel = 0
    case .Knockback:
	entity.vel += hit_force
    }
}

entity_update :: proc(gs: ^Game_State, dt: f32) {
    for &e in gs.entities {
	if e.health == 0 && .Immortal not_in e.flags {
	    e.flags += {.Dead}
	}

	if e.hit_timer > 0 {
	    e.hit_timer -= dt
	    
	    if e.hit_timer <= 0 {
		#partial switch e.hit_response {
		case .Stop:
		    e.behaviors += {.Walk}
		    e.flags -= {.Frozen}
		}
	    }
	}

	if len(e.animations) > 0 {
	    anim := e.animations[e.current_anim_name]

	    // Switch Frames
	    if .Frozen not_in e.flags {
		e.animation_timer -= dt
	    }

	    if e.animation_timer <= 0 {
		e.current_anim_frame += 1
		e.animation_timer = anim.time

		// Loop, TODO: Reverse, Stop
		if .Loop in anim.flags {
		    if e.current_anim_frame > anim.end {
			e.current_anim_frame = anim.start
		    }
		}
		else {
		    if e.current_anim_frame > anim.end {
			e.current_anim_frame -= 1

			if anim.on_finish != nil {
			    anim.on_finish(gs, &e)
			}
		    }
		}
	    }

	    // Event handeling
	    for &event in anim.timed_events {
		if event.timer > 0 {
		    event.timer -= dt

		    if event.timer <= 0 {
			event.callback(gs, &e)
			
		    }
		}
	    }
	}
    }
}
