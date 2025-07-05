# MCPy: High-Performance Minecraft Server Engine

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Python 3.9+](https://img.shields.io/badge/python-3.9+-blue.svg)](https://www.python.org/downloads/)
[![Cython](https://img.shields.io/badge/Cython-0.29.34+-darkgreen.svg)](https://cython.org/)

A production-grade, ultra-optimized Minecraft server engine built with Python, Cython, and scientific computing libraries. This project aims to deliver exceptional performance while maintaining the flexibility and accessibility of Python.



## 🚀 Key Features

- **Ultra-optimized Core**: Cython-accelerated server core achieving near-C performance
- **Scientific Computing Foundation**: Leverages NumPy, SciPy, and Polars for high-performance operations
- **Zero-overhead Networking**: Asynchronous, non-blocking network stack with protocol optimization
- **Advanced Entity System**: Efficient entity management with specialized AI behaviors
- **ORM-based Persistence**: PostgreSQL integration with SQLAlchemy for robust data storage
- **Comprehensive Benchmarking**: Built-in performance analysis and optimization tools
- **Plugin Framework**: Extensible architecture for custom server modifications
- **Real-time Monitoring**: Prometheus/Grafana integration for server metrics

## 📐 Architecture

MCPy is built on five specialized core modules, each carefully designed for maximum performance:

1. **`server_core.pyx`**: Central server management
   - Event-driven architecture for request handling
   - Efficient worker thread pool management
   - Optimized tick system with adaptive timing
   - Performance profiling and bottleneck detection

2. **`world_engine.pyx`**: Procedural world generation
   - Scientifically accurate noise generation algorithms
   - Multi-threaded chunk generation and loading
   - Memory-efficient terrain representation
   - Advanced biome generation systems

3. **`network_core.pyx`**: High-performance networking
   - Zero-copy packet serialization
   - Protocol-level compression and optimization
   - Connection pooling and management
   - DDoS protection mechanisms

4. **`entity_system.pyx`**: Efficient entity lifecycle management
   - Spatial hash-based entity tracking
   - Multi-threaded physics simulation
   - AI behavior system with path-finding
   - Memory-efficient entity representation

5. **`persistence`**: Database integration
   - SQLAlchemy ORM for PostgreSQL/SQLite data storage
   - Efficient chunk serialization and compression
   - Transactional world state management
   - Optimized query patterns for game data

## 📊 Performance Goals

- **Scalability**: Maintain 20 TPS with 100+ concurrent players
- **Memory Efficiency**: Keep memory usage under 2GB for 10,000 chunks
- **Low Latency**: Achieve < 50ms latency per player action
- **Reliability**: Implement 100% test coverage for core modules
- **Throughput**: Process 10,000+ entity updates per tick

## ⚙️ Technical Implementation

### Cython Optimization Strategies
MCPy uses several advanced Cython techniques to achieve C-like performance:
- Static typing with `cdef` variables and functions
- Memory management with pointer arithmetic where necessary
- Compiler directives for bounds checking and wraparound elimination
- Numpy integration with direct buffer access
- Efficient parallelization with thread pools

### Entity System Design
The entity system features:
- Hierarchical class structure for specialized entity behaviors
- Spatial partitioning for O(1) entity lookup in areas of interest
- Component-based design for extensibility
- Custom memory pools for entity allocation
- Adaptive entity LOD (Level of Detail) based on distance

### World Generation Algorithm
World generation implements:
- Multi-octave Perlin and Simplex noise combinations
- Biome transitions using Voronoi diagrams
- Scientifically accurate erosion and cave formation algorithms
- Structure generation using grammar-based systems
- Custom chunk compression for 10x storage efficiency

## 📦 Installation

### Prerequisites
- Python 3.9+ (3.11 recommended for best performance)
- C++ compiler (Visual Studio 2019+ on Windows, GCC 9+ on Linux)
- PostgreSQL 13+ (optional, for production environments)
- 8GB RAM minimum (16GB recommended)

### Quick Setup (Windows/Linux/macOS)

```bash
# Clone the repository
git clone https://github.com/magi8101/mcpy.git
cd mcpy

# Run the all-in-one setup script
# On Windows:
setup.bat

# On Linux/macOS:
chmod +x setup.sh
./setup.sh
```

This script handles:
- Setting up a virtual environment
- Installing all dependencies
- Building Cython modules
- Initializing Git repository

### Manual Installation (Windows/Linux/macOS)

```bash
# Clone the repository
git clone https://github.com/magi8101/mcpy.git
cd mcpy

# Create a virtual environment
python -m venv .venv
# On Windows:
.venv\Scripts\activate
# On Linux/macOS:
source .venv/bin/activate

# Install dependencies from requirements file
pip install -r _requirements.txt

# Install the package in development mode
pip install -e ".[dev]"

# Optional AI features (requires extra CPU/GPU resources)
pip install -e ".[ai]"

# Verify dependencies are correctly installed
python check_dependencies.py

# Rebuild Cython modules
python setup.py build_ext --inplace
```

## 🚀 Running the Server

```bash
# Using the setup scripts to run the server
# On Windows:
setup.bat run

# On Linux/macOS:
./setup.sh run

# Basic server start from command line
python -m mcpy.server

# With custom config and world path
python -m mcpy.server --config custom_config.toml --world my_world

# Performance mode with additional optimizations
python -m mcpy.server --performance-mode --max-players 100

# Debug mode with increased logging
python -m mcpy.server --debug --log-level debug
```

### Command Line Options

| Option | Description |
|--------|-------------|
| `--config PATH` | Path to custom TOML configuration file |
| `--world PATH` | Path to world directory |
| `--port NUMBER` | Network port (default: 25565) |
| `--max-players NUMBER` | Maximum number of players (default: 20) |
| `--view-distance NUMBER` | Chunk view distance (default: 10) |
| `--performance-mode` | Enables additional optimizations |
| `--debug` | Enables debug mode |
| `--log-level LEVEL` | Set logging level (default: info) |
| `--backup` | Enable automatic backups |

## 🗄️ Database Configuration

MCPy supports both SQLite (for development) and PostgreSQL (for production) databases. Configure these settings in your `config.toml` file:

### SQLite (Default)
```toml
[database]
type = "sqlite"
path = "world/mcpy.db"
journal_mode = "WAL"  # Write-Ahead Logging for better concurrency
synchronous = "NORMAL"  # Balance between safety and performance
```

### PostgreSQL (Recommended for Production)
```toml
[database]
type = "postgresql"
host = "localhost"
port = 5432
dbname = "mcpy"
user = "postgres"
password = "your_password"
pool_size = 10
max_overflow = 20
echo = false  # Set to true for query debugging
```

## 💾 Persistence Implementation

The persistence layer uses SQLAlchemy ORM with these key features:

- **Transactional World Saving**: 
  ```python
  with session.begin():
      for chunk in dirty_chunks:
          session.add(ChunkModel.from_chunk(chunk))
  ```

- **Efficient Chunk Serialization**:
  ```python
  # Chunks are serialized using NumPy's efficient binary format
  chunk_data = np.savez_compressed(io_buffer, 
                                  blocks=chunk.blocks,
                                  heightmap=chunk.heightmap,
                                  biomes=chunk.biomes)
  ```

- **Player Data Management**:
  ```python
  # Player data is stored as a JSON document with binary inventories
  player_model = PlayerModel(
      uuid=player.uuid,
      username=player.username,
      position=json.dumps([player.x, player.y, player.z]),
      inventory=pickle.dumps(player.inventory, protocol=5),
      stats=json.dumps(player.stats)
  )
  ```

- **Auto-saving System**:
  Implements an intelligent dirty-tracking system that only saves modified chunks and entities.
  
- **Backup Management**:
  Automated world backups with configurable intervals and retention policies.

## 🧪 Development and Testing

```bash
# Run the full test suite
pytest

# Run only entity system tests
pytest tests/test_entity_system.py

# Run benchmarks
python -m benchmarks.benchmark

# Profile a specific module
python -m mcpy.profiling.profile_module world_engine

# Generate test coverage report
pytest --cov=mcpy --cov-report=html
```

### Performance Tuning

1. **Entity System Optimization**:
   ```python
   # Use spatial hashing for entity collision detection
   entity_spatial_hash = {(int(e.x/16), int(e.z/16)): [] for e in entities}
   for entity in entities:
       entity_spatial_hash[(int(entity.x/16), int(entity.z/16))].append(entity)
   ```

2. **World Engine Tuning**:
   ```python
   # Parallelize chunk generation
   with ThreadPoolExecutor(max_workers=os.cpu_count()) as executor:
       futures = [executor.submit(generate_chunk, x, z) for x, z in chunk_coords]
       chunks = [f.result() for f in futures]
   ```

3. **Network Optimization**:
   ```python
   # Use zero-copy buffer protocol for packet serialization
   cdef char* buffer = <char*>malloc(packet_size)
   memcpy(buffer, &packet_header, sizeof(packet_header))
   memcpy(buffer + sizeof(packet_header), packet_data, packet_data_size)
   ```

## 🔧 Advanced Features

### Plugin System

MCPy includes a powerful plugin system that allows for server extensions without modifying core code:

```python
# Example plugin: Custom command handler
from mcpy.plugins import Plugin, event

class TeleportPlugin(Plugin):
    @event("player.command")
    def on_command(self, player, command, args):
        if command == "tp" and len(args) >= 1:
            target_name = args[0]
            target = self.server.get_player_by_name(target_name)
            if target:
                player.teleport(target.x, target.y, target.z)
                return True
        return False
```

### Real-time Monitoring

Integrate with Prometheus and Grafana for comprehensive server monitoring:

```python
# In your server configuration
[monitoring]
enabled = true
prometheus_port = 9090
metrics = ["tps", "memory_usage", "players_online", "chunks_loaded"]
```

### AI Entity Behaviors

Advanced entity AI using behavior trees and pathfinding:

```python
# Example of AI behavior system implementation
class ZombieAI(MobAI):
    def setup_behaviors(self):
        self.behaviors = BehaviorTree(
            Selector([
                # Attack nearby players
                Sequence([
                    CheckPlayerNearby(radius=16),
                    PathfindToPlayer(),
                    AttackPlayer()
                ]),
                # Wander around
                Sequence([
                    Wait(random.randint(20, 100)),
                    MoveToRandomPosition(radius=10)
                ])
            ])
        )
```

## 🗺️ Development Roadmap

### Short-term Goals
- [ ] Complete entity collision system
- [ ] Implement crafting and inventory management
- [ ] Add basic combat mechanics
- [ ] Improve world generation performance

### Medium-term Goals
- [ ] Multi-world support with portals
- [ ] Custom block behaviors
- [ ] Enhanced mob AI and pathfinding
- [ ] In-game scripting API

### Long-term Goals
- [ ] Distributed server architecture for massive worlds
- [ ] Machine learning for adaptive mob behavior
- [ ] Real-time ray-traced lighting system
- [ ] Custom physics engine optimizations

## 📝 Contributing

Contributions are welcome! Please check out our [Contributing Guide](CONTRIBUTING.md) to get started.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
