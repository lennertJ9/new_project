class_name NetworkProtocol
extends RefCounted

const VERSION: int = 1

const CHANNEL_CONTROL: int = 0
const CHANNEL_MOVEMENT: int = 1
const CHANNEL_WORLD: int = 2

enum MessageType {
	HELLO = 0,
	HELLO_ACCEPTED = 1,
	REJECT = 2,
	WORLD_SNAPSHOT = 3,
	CLIENT_WORLD_READY = 4,
	PLAYER_SPAWN = 5,
	PLAYER_DESPAWN = 6,
	PLAYER_INPUT = 7,
	PLAYER_STATE = 8,
	REQUEST_DAMAGE_WALL = 9,
	WALL_STATE = 10,
}
