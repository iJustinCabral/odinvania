package game

import rl "vendor:raylib"
import    "core:time"

// Constants
PHYSICS_ITERATIONS :: 8
GRAVITY            :: 5
TERMINAL_VELOCITY  :: 1200
COLLISION_EPSILON  :: 0.01


// First two parameters take a slice []T
// Slies are Pointer + Length
// Last paramater is the Delta Time
physics_update :: proc(entities: []Entity, static_colliders: []Rect, dt: f32) {
    for &entity, e_id in entities {
	// Skip the dead entities
	entity_id := Entity_ID(e_id)
	if .Dead in entity.flags do continue
	
	// Multiple interations provide a more stable physics sim
	// Helps prevent tunneling through wall at higher speeds
	// Also known as Discrete Collision Detection
	if .Kinematic not_in entity.flags {
	    for _ in 0 ..<PHYSICS_ITERATIONS {
		step := dt / PHYSICS_ITERATIONS
		entity.vel.y += GRAVITY

		if entity.vel.y > TERMINAL_VELOCITY {
		    entity.vel.y = TERMINAL_VELOCITY
		}

		// Updating each axis seperately recudes edge cases
		// Updaing both .x and .y at the same time can cause colliders to get stuck in walls or go through them
		// It also allows to easily sperate converns, such as setting is_grounded

		// Y Axis
		entity.y += entity.vel.y * step
		entity.flags -= {.Grounded}

		for static in static_colliders {
		    // This checks if two rectangles overlap
		    // Example below
		    // +------+
		    // |      |
		    // |      |
		    // |  +---+-+
		    // |  | X | |
		    // +--+---+ |
		    //    +-----+
		    if rl.CheckCollisionRecs(entity.collider, static) {
			if entity.vel.y > 0 {
			    // Moving rectnagle is above the static collider
			    // High enough veloicty may not always be true
			    // This is why we use multiple iterations
			    entity.y = static.y - entity.height
			    entity.flags += {.Grounded}
			} else {
			    entity.y = static.y + static.height
			}
			entity.vel.y = 0
			break
		    }
		}

		// X Axis
		entity.x += entity.vel.x * step
		for static in static_colliders {
		    if rl.CheckCollisionRecs(entity.collider, static) {
			if entity.vel.x > 0 {
			    // Moving rectangle is left of static
			    entity.x = static.x - entity.width
			} else {
			    entity.x = static.x + static.width
			}
			entity.vel.x = 0
			break
		    }
		}
	    }
	}

	// Collisions Event Handling
	for &other, o_id in entities {
	    other_id := Entity_ID(o_id)
	    if entity_id == other_id do continue

	    if rl.CheckCollisionRecs(entity, other.collider) {
		if entity_id not_in other.entity_ids {
		    other.entity_ids[entity_id] = time.now()

		    if other.on_enter != nil {
			other.on_enter(other_id, entity_id)
		    }
		}
		else {
		    if other.on_stay != nil {
			other.on_stay(other_id, entity_id)
		    }
		}
	    }
	    else if entity_id in other.entity_ids {
		if other.on_exit != nil {
		    other.on_exit(other_id, entity_id)
		}
		delete_key(&other.entity_ids, entity_id)
	    }
	}

    }
}

raycast :: proc(start, magnitude: Vec2, targets: []Rect, allocator := context.temp_allocator) -> (hits: []Vec2, ok: bool) {
    hit_store := make([dynamic]Vec2, allocator)

    for t in targets {
	p,q,r,s: Vec2 = {t.x, t.y}, {t.x, t.y + t.height}, {t.x + t.width, t.y + t.height}, {t.x + t.width, t.y}
	lines := [4][2]Vec2{{p,q}, {q,r}, {r,s}, {s,p}}

	for line in lines {
	    point: Vec2
	    if rl.CheckCollisionLines(start, start + magnitude, line[0], line[1], &point) {
		append(&hit_store, point)
	    }
	}

	color := len(hit_store) > 0 ? rl.GREEN : rl.YELLOW
	debug_draw_line(start, start + magnitude, 1, color)
    }

    return hit_store[:], len(hit_store) > 0
}
