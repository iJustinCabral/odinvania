package game

player_on_enter :: proc(self_id, other_id: Entity_ID) {
    player := entity_get(self_id)
    other := entity_get(other_id)

    if other.on_hit_damage > 0 {
	player.health -= other.on_hit_damage
    }
}
