package game

import rl "vendor:raylib"
import "core:fmt"
import "core:math/linalg"

Player_Movement_State :: enum {
    Uncontrollable,
    Attacking,
    Attack_Cooldown,
    Idle,
    Run,
    Jump,
    Fall,
}

player_update :: proc(gs: ^Game_State, dt: f32) {

  

    player := entity_get(gs.player_id)

    input_x: f32
    if rl.IsKeyDown(.D) do input_x += 1
    if rl.IsKeyDown(.A) do input_x -= 1

    player.vel.x = input_x * player.move_speed

    if player.vel.x > 0 do player.flags -= {.Left}
    if player.vel.x < 0 do player.flags += {.Left}

    if gs.attack_recovery_timer > 0 {
	gs.attack_recovery_timer -= dt
	player.vel *= 0.5
    }

    gs.jump_timer -= dt
    gs.coyote_timer -= dt

    switch gs.player_movement_state {
    case .Uncontrollable:
	gs.safe_reset_timer -= dt
	player.vel.x = 0
	player.vel.y = 0
	if gs.safe_reset_timer <= 0 {
	    switch_animation(player, "idle")
	    gs.player_movement_state = .Idle
	}
    case .Attacking:
	if .Grounded in player.flags {
	    player.vel.x = 0
	}
    case .Attack_Cooldown:
	gs.attack_cooldown_timer -= dt
	if gs.attack_cooldown_timer <= 0 {
	    gs.player_movement_state = .Idle
	}
	try_run(gs, player)
    case .Idle:
	try_run(gs, player)
	try_jump(gs, player)
	try_attack(gs, player)
    case .Run:
	if input_x == 0 {
	    gs.player_movement_state = .Idle
	    switch_animation(player, "idle")
	}
	try_jump(gs, player)
	try_attack(gs, player)
    case .Jump:
	if rl.IsKeyReleased(.SPACE) {
	    player.vel.y *= 0.5
	}

	if player.vel.y >= 0 {
	    gs.player_movement_state = .Fall
	    player.current_anim_name = "fall"
	    switch_animation(player, "fall")
	}
	try_attack(gs, player)
    case .Fall:
	if .Grounded in player.flags {
	    gs.player_movement_state = .Idle
	    switch_animation(player, "idle")
	}
	try_attack(gs, player)
    }    

    for spike in gs.spikes {
	if rl.CheckCollisionRecs(spike.collider, player.collider) {
		player.x = gs.safe_position.x
		player.y = gs.safe_position.y
		player.vel = 0
		gs.safe_reset_timer = PLAYER_SAFE_RESET_TIME
		gs.player_movement_state = .Uncontrollable
		switch_animation(player, "idle")
	}
    }
}

player_on_enter :: proc(self_id, other_id: Entity_ID) {
    player := entity_get(self_id)
    other := entity_get(other_id)

    if other.on_hit_damage > 0 {
	player.health -= other.on_hit_damage
    }
}

player_on_finish_attack :: proc(gs: ^Game_State, player: ^Entity) {
    switch_animation(player, "idle")
    gs.player_movement_state = .Attack_Cooldown
}

player_attack_callback :: proc(gs: ^Game_State, player: ^Entity) {
    center := Vec2{player.x, player.y}
    center += {.Left in player.flags ? -30 + player.collider.width : 30, 20}

    for &e, idx in gs.entities {
	id := Entity_ID(idx)
	if id == gs.player_id do continue
	if .Dead in e.flags do continue
	if .Immortal in e.flags do continue

	if rl.CheckCollisionCircleRec(center, 25, e.collider) {
	    entity_damage(Entity_ID(idx), 1)
	}

	a := rect_center(player.collider)
	b := rect_center(e.collider)
	dir := linalg.normalize0(b - a)

	player.vel.x = -dir.x * 500
	player.vel.y = -dir.y * 200 - 100

	gs.attack_recovery_timer = ATTACK_RECOVERY
	entity_hit(Entity_ID(idx), dir * 500)
    }

    for &falling_log in gs.falling_logs {
	if falling_log.state != .Default do continue

	log_center := rect_center(falling_log.collider)
	rope_pos := Vec2{log_center.x, log_center.y - falling_log.collider.height / 2}
	rect := Rect {
		rope_pos.x - 1,
		rope_pos.y - falling_log.rope_height,
		2,
		falling_log.rope_height - TILE_SIZE,
	}

	if rl.CheckCollisionCircleRec(center, 25, rect) {
		falling_log.state = .Falling
	}
    }
}

try_run :: proc(gs: ^Game_State, player: ^Entity) {
    if player.vel.x != 0 && .Grounded in player.flags {
	switch_animation(player, "run")
	gs.player_movement_state = .Run
    }
}

try_jump :: proc(gs: ^Game_State, player: ^Entity) {
    if rl.IsKeyPressed(.SPACE) {
	gs.jump_timer = JUMP_TIME
    }

    if .Grounded in player.flags {
	gs.coyote_timer = COYOTE_TIME
    }

    if (.Grounded in player.flags || gs.coyote_timer > 0) && gs.jump_timer > 0 {
	player.vel.y = -player.jump_force
	player.flags -= {.Grounded}
	switch_animation(player, "jump")
	gs.player_movement_state = .Jump
    }


}

try_attack :: proc(gs: ^Game_State, player: ^Entity) {
    if rl.IsMouseButtonPressed(.LEFT) {
	switch_animation(player, "attack")
	gs.player_movement_state = .Attacking
	gs.attack_cooldown_timer = ATTACK_COOLDOWN
    }
}
