extends Node3D
class_name AISpawner

# Basic spawner variables
var agents: Node
var activeAgents: int = 0
var spawnLimit: int = 10
var spawnDistance: float = 50.0
var active: bool = true

# Agent scene to spawn
var agent: PackedScene

# Spawn pools
var APool: Node
var spawnPool: int = 0

# Points arrays
var spawns: Array = []
var waypoints: Array = []
var patrols: Array = []
var covers: Array = []
var hides: Array = []

# Initial spawn settings
var initialGuard: int = 0
var initialHider: int = 0
var noHiding: bool = false

func _ready():
    # Initialize basic structure
    agents = Node.new()
    agents.name = "Agents"
    add_child(agents)

    APool = Node.new()
    APool.name = "APool"
    add_child(APool)

# Basic spawn method - to be overridden by child classes
func spawn(spawn_position = null):
    # Default implementation - does nothing
    # Child classes should implement actual spawning logic
    pass

# Get spawn points - to be implemented by child
func GetPoints():
    pass

# Hide points - to be implemented by child
func HidePoints():
    pass

# Create pools - to be implemented by child
func CreatePools():
    pass