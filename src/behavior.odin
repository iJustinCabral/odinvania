package game

behavior_update :: proc(entities: []Entity, static_colliders: []Rect, dt: f32) {
    for &e in entities {
	if .Dead in e.flags do continue // dont run behavior code for dead entities

	if .Walk in e.behaviors {
	    if .Left in e.flags {
		e.vel.x = -e.move_speed
	    } else {
		e.vel.x = e.move_speed
	    }
	}

	if .Flip_At_Wall in e.behaviors {
	    if .Left in e.flags {
		if _, ok := raycast(
		    {e.x + e.width / 2, e.y + e.height / 2},
		    {-e.width / 2 - COLLISION_EPSILON, 0},
		    static_colliders,
		)
		ok{ 
		    e.flags += {.Left}
		    e.vel.x = 0
		}
	    }
	    else {
		if _, ok := raycast(
		    {e.x + e.width / 2, e.y + e.height / 2},
		    {e.width / 2 + COLLISION_EPSILON, 0},
		    static_colliders
		)
		ok {
		    e.flags += {.Left}
		    e.vel.x = 0
		}
	    }
	}

	// Ground check because otherwise the direction will flip every tick while falling
	if .Flip_At_Edge in e.behaviors && .Grounded in e.flags {
	    if .Left in e.flags {
		start := Vec2{e.x, e.y + e.height / 2}
		magnitude := Vec2{0, e.height / 2 + COLLISION_EPSILON}

		if hits, ok := raycast(start, magnitude, static_colliders)
		!ok {
		    e.flags -= {.Left}
		    e.vel.x = 0
		}
	    }
	    else {
		start := Vec2{e.x + e.width, e.y + e.height / 2}
		magnitude := Vec2{0, e.height / 2 + COLLISION_EPSILON}
		if its, ok := raycast(start, magnitude, static_colliders)
		!ok {
		    e.flags += {.Left}
		    e.vel.x = 0
		}
	    }
	}
    }
}
