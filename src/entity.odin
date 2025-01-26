package game

import "core:time"
import rl "vendor:raylib"

Entity :: struct {
    using collider: Rect,
    vel:	    Vec2,
    move_speed:     f32,
    jump_force:     f32,
    on_enter, on_stay, on_exit: proc(self_id, other_id: Entity_ID),
    entity_ids:     map[Entity_ID]time.Time,
    flags:          bit_set[Entity_Flags],
    debug_color:     rl.Color,
    
} 

// Distinct make sure two ints for the ID will never be the same
Entity_ID :: distinct int

Entity_Flags :: enum {
    Grounded,
    Dead,
    Kinematic,
    Debug_Draw,
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
