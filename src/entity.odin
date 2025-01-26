package game

Entity :: struct {
    using collider: Rect,
    vel:	    Vec2,
    move_speed:     f32,
    jump_force:     f32,
    is_grounded:    bool,
    is_dead:        bool,
} 

entity_create :: proc(entity: Entity) -> int {
    for &e, i in gs.entities {
	if e.is_dead {
	    e = entity
	    e.is_dead = false
	    return i 
	}
    }

    index := len(gs.entities)
    append(&gs.entities, entity)

    return index
}

entity_get :: proc(id: int) -> ^Entity {
    return &gs.entities[id]
}
