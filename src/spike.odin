package game

import "core:fmt"

SPIKE_BREADTH :: 16
SPIKE_DEPTH   :: 12
SPIKE_DIFF    :: TILE_SIZE - SPIKE_DEPTH

Direction :: enum {
    Up,
    Right,
    Down,
    Left
}

spike_on_enter :: proc(self_id, other_id: Entity_ID) {
    self := entity_get(self_id)
    assert(self != nil)

    other := entity_get(other_id)
    assert(self != nil)

    if other_id == gs.player_id {
	other.x = gs.safe_position.x
	other.y = gs.safe_position.y
	other.vel = 0
	gs.safe_reset_timer = PLAYER_SAFE_RESET_TIME
	gs.player_movement_state = .Uncontrollable
	switch_animation(other, "idle")
    }

    dir := gs.spikes[self_id]
    switch dir {
    case .Up:
	if other.vel.y > 0 { fmt.println("Spike face Up") }
    case .Right:
	if other.vel.x < 0 { fmt.println("Spike face Right") }
    case .Down:
	if other.vel.y < 0 { fmt.println("Spike face Down") }
    case .Left:
	if other.vel.x > 0 { fmt.println("Spike face Left") }
    }
}
