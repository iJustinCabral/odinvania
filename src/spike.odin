package game

import "core:fmt"

SPIKE_BREADTH :: 16
SPIKE_DEPTH   :: 12
SPIKE_DIFF    :: TILE_SIZE - SPIKE_DEPTH

Spike :: struct {
    collider: Rect,
    facing: Direction,
}

Falling_Log :: struct {
    collider: Rect,
    rope_height: f32,
    state: enum { Default, Falling, Settled },
}

Direction :: enum {
    Up,
    Right,
    Down,
    Left
}


