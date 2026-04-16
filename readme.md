# Bo's War: Advanced Enemy AI Mod for Road to Vostok

[![Godot](https://img.shields.io/badge/Godot-4.x-blue.svg)](https://godotengine.org/)
[![Version](https://img.shields.io/badge/Version-0.0.1-orange.svg)]()
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

An advanced enemy AI enhancement mod for the game *Road to Vostok*, introducing sophisticated AI behaviors, faction-based warfare, and configurable difficulty systems.

## 🎯 Overview

Bo's War transforms the enemy AI in Road to Vostok from basic scripted behaviors into intelligent, adaptive opponents that provide challenging and immersive gameplay experiences. The mod introduces faction-based targeting, audio sensing, tactical waypoint navigation, and configurable difficulty presets.

## Quick Guide

- when creating the mod on latest windows or mac, just use an empty .zip file;
- drag the folders and files you need in the mod into the .zip file
- copy the .zip file into your game mods folder
- rename .zip extension into .vmz
- and you are ready to play

## ✨ Key Features

### 🤖 Advanced AI Behaviors
- **Faction-Based Targeting**: Enemies distinguish between player, allies, and rival factions
- **Audio Sensing**: AI can detect gunfire and movement sounds from a distance
- **Tactical Navigation**: Intelligent use of cover points, waypoints, and hiding spots
- **State Machine**: Dynamic behavior states (Wander, Combat, Hide, Patrol, etc.)
- **Hysteresis Targeting**: Prevents target switching thrashing for stable engagements

### ⚔️ Combat Enhancements
- **Configurable Accuracy**: Adjustable AI accuracy multipliers
- **Difficulty Presets**: Passive, Default, Aggressive, and Relentless AI behaviors
- **Performance Scaling**: AI complexity adjusts based on active agent count
- **Boss Mechanics**: Enhanced elite enemies with special behaviors

### 🏰 Faction Warfare System
- **Inter-Faction Combat**: Configurable warfare between different enemy factions
- **Infighting**: Optional same-faction combat for dynamic encounters
- **Player Alignment**: Potential for player to ally with specific factions

### 🔧 Configuration & Modding
- **Mod Configuration Menu (MCM) Support**: In-game settings adjustment
- **Resource-Based Settings**: Easy configuration through `.tres` files
- **Debug Tools**: Comprehensive logging and visual debug overlays
- **Performance Monitoring**: Real-time AI status and performance metrics

## 📁 Project Structure

```
road-to-vostok-mod/
├── BosWar/                    # Main mod files
│   ├── AI.gd                 # Core AI behavior script
│   ├── AISpawner.gd          # AI spawning system
│   ├── EnemyAISettings.gd    # Configuration resource
│   ├── EnemyAISettings.tres  # Settings resource instance
│   ├── Main.gd               # Main system coordinator
│   └── MCMCompat_Main.gd     # MCM compatibility
├── docs/                     # Documentation and plans
│   └── plans/               # Development plans and TODOs
├── mods/                     # Reference mods
├── Reference Scripts/        # Base game script references
├── realistic shaders/        # Enhanced visual effects
└── mod.txt                   # Mod metadata
```

## 🚀 Installation

### Prerequisites
- **Road to Vostok** game installed
- **Godot 4.x** (for development/modding)

### Mod Installation
1. Download the latest release from the [Releases](../../releases) page
2. Extract the `BosWar` folder to your Road to Vostok mods directory
3. Ensure the mod is enabled in your mod manager
4. Launch the game

### Development Setup
1. Clone this repository:
   ```bash
   git clone https://github.com/yourusername/road-to-vostok-mod.git
   cd road-to-vostok-mod
   ```

2. Open the project in Godot 4.x:
   ```bash
   godot --path .
   ```

3. Configure your development environment for Road to Vostok modding

## ⚙️ Configuration

### Basic Settings
The mod can be configured through the in-game Mod Configuration Menu (MCM) or by editing `EnemyAISettings.tres`:

- **AI Difficulty**: Choose from Passive, Default, Aggressive, or Relentless
- **Sight Multiplier**: Adjust AI vision range (0.1x to 5.0x)
- **Accuracy Multiplier**: Control AI shooting accuracy
- **Faction Warfare**: Enable/disable inter-faction combat
- **Infighting**: Allow same-faction combat

### Advanced Configuration
For advanced users, modify the settings in `EnemyAISettings.gd`:

```gdscript
@export var ai_health_multiplier: float = 1.0
@export var ai_sight_multiplier: float = 1.0
@export_range(0.1, 5.0, 0.1) var ai_accuracy_multiplier: float = 1.0
@export var bandit_infighting_enabled: bool = false
@export var enable_faction_warfare: bool = true
```

## 🎮 Usage

### In-Game Features
- **Enhanced Enemy Behavior**: AI now uses cover, flanks, and tactical positioning
- **Audio Awareness**: Enemies react to distant gunfire and investigate sounds
- **Faction Dynamics**: Different enemy groups may fight each other
- **Scalable Difficulty**: Adjust AI challenge without restarting

### Debug Mode
Enable debug mode in settings to see:
- AI state indicators
- Target lines
- Performance metrics
- Behavior logging

## 🛠️ Development

### Architecture
The AI system follows a modular architecture:
- **AI.gd**: Main AI controller with state machine
- **AISpawner.gd**: Population management and spawning
- **EnemyAISettings.gd**: Configuration management
- **DebugUtils.gd**: Development and debugging tools

### Coding Standards
See [AGENTS.md](AGENTS.md) for detailed coding conventions and architectural patterns.

### Planned Enhancements
See [docs/plans/TODO.md](docs/plans/TODO.md) for upcoming features including:
- Cooperative squad behaviors
- Advanced combat tactics (grenades, suppressive fire)
- Learning and adaptation systems
- Personality variations
- Performance optimizations

### Contributing
1. Fork the repository
2. Create a feature branch: `git checkout -b feature/amazing-feature`
3. Commit your changes: `git commit -m 'Add amazing feature'`
4. Push to the branch: `git push origin feature/amazing-feature`
5. Open a Pull Request

## 📊 Performance

The mod is optimized for performance:
- **Distance-based processing**: Reduced updates for distant AI
- **Pool management**: Efficient agent spawning/destruction
- **Configurable limits**: Adjustable maximum active agents
- **LOD system**: Simplified behavior for performance

Recommended settings for different hardware:
- **Low-end**: Max 32 agents, reduced sight ranges
- **Mid-range**: Max 64 agents, default settings
- **High-end**: Max 128+ agents, enhanced features

## 🐛 Troubleshooting

### Common Issues
- **AI not spawning**: Check mod installation and mod.txt autoloads
- **Performance issues**: Reduce max agents or increase update intervals
- **Faction warfare not working**: Verify faction settings in configuration

### Debug Tools
Enable debug logging in `EnemyAISettings.gd`:
```gdscript
@export var enable_debug_logging: bool = true
@export var show_debug_overlay: bool = true
```

### Logs
Check Godot's console output for AI-related messages and errors.

## 📝 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- **Road to Vostok** development team for the base game
- **Godot Engine** community for the excellent game engine
- **Modding Community** for inspiration and shared knowledge

## 📞 Support

- **Issues**: [GitHub Issues](../../issues)
- **Discussions**: [GitHub Discussions](../../discussions)
- **Wiki**: [Project Wiki](../../wiki)

---

**Made with ❤️ for the Road to Vostok community**