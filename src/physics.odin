package game

import rl "vendor:raylib"

// Constants
PHYSICS_ITERATIONS :: 8
GRAVITY            :: 5
TERMINAL_VELOCITY  :: 1200


// First two parameters take a slice []T
// Slies are Pointer + Length
// Last paramater is the Delta Time
physics_update :: proc(entities: []Entity, static_colliders: []Rect, dt: f32) {
    for &entity in entities {
	// Skip the dead entities
	if entity.is_dead do continue
	
	// Multiple interations provide a more stable physics sim
	// Helps prevent tunneling through wall at higher speeds
	// Also known as Discrete Collision Detection
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
	    entity.is_grounded = false

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
			entity.is_grounded = true
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
}
