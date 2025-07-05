# MCPy: High-Performance Minecraft Server Engine
# please visit our error log [error-log](errorlog\error-1.md) and contributions are welcomed for solving error 

> **Note:** _MCPy is currently in active development, is **not completed**, and contains many errors. We are working hard to resolve outstanding issues. Your contributions are highly welcomed!_

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Python 3.9+](https://img.shields.io/badge/python-3.9+-blue.svg)](https://www.python.org/downloads/)
[![Cython](https://img.shields.io/badge/Cython-0.29.34+-darkgreen.svg)](https://cython.org/)

---

MCPy is a next-generation, ultra-optimized Minecraft server engine, blending the power of Python, Cython, and advanced scientific computing libraries. Our aim is to deliver exceptional performance and flexibility, making Minecraft server development accessible and future-proof.

---

## 🚧 Project Status

- **This project is NOT COMPLETED and currently contains many known errors.**
- Major features are still under development and the codebase is unstable.
- Contributions and bug reports are highly appreciated to help us reach a stable release.

---

## 🚀 Features at a Glance

- **Blazing Fast Core**: Cython-accelerated, event-driven server engine with near-C performance.
- **Scientific Computing Backbone**: Integrates NumPy, SciPy, and Polars for high-performance operations.
- **Zero-Overhead Networking**: Asynchronous, non-blocking, protocol-optimized networking.
- **Sophisticated Entity System**: Efficient, extensible entity management supporting advanced AI behaviors.
- **Robust Persistence Layer**: PostgreSQL and SQLAlchemy-powered ORM for reliable data storage.
- **Comprehensive Benchmarking**: Built-in performance analytics and profiling tools.
- **Extensible Plugin Framework**: Easily add server modifications with minimal friction.
- **Real-time Monitoring**: First-class Prometheus & Grafana integration for live metrics.

---

## 📐 Architecture Overview

MCPy is modular by design, comprising five high-performance core components:

### 1. `server_core.pyx`
- Event-driven request handling
- Adaptive, high-precision tick system
- Dynamic worker thread pool management
- Real-time performance profiling & bottleneck detection

### 2. `world_engine.pyx`
- Procedural terrain with multi-octave noise & advanced biome transitions
- Multi-threaded chunk generation & memory-efficient terrain storage
- Complex structure and cave generation algorithms

### 3. `network_core.pyx`
- Zero-copy packet serialization & protocol-level compression
- Robust connection pooling & DDoS mitigation

### 4. `entity_system.pyx`
- Spatial hash-based entity tracking, multi-threaded physics simulation
- Modular AI behavior trees & efficient entity representation

### 5. `persistence`
- SQLAlchemy ORM for PostgreSQL/SQLite
- Efficient chunk serialization, transactional world state, and optimized queries

---

## 📊 Performance Goals

| Metric                | Target Value                          |
|-----------------------|---------------------------------------|
| Scalability           | 20 TPS with 100+ concurrent players   |
| Memory Usage          | < 2GB for 10,000 chunks               |
| Latency               | < 50ms per player action              |
| Reliability           | 100% test coverage for core modules   |
| Throughput            | 10,000+ entity updates per tick       |

---

## ⚙️ Technical Highlights

### Cython & Performance
- Static typing with `cdef`, aggressive use of compiler directives
- Direct NumPy buffer access, pointer arithmetic for critical paths
- Multi-threaded parallelism using thread pools

### Entity System
- Hierarchical, component-based design
- Spatial partitioning for O(1) lookup
- Custom memory pools & adaptive Level-of-Detail (LOD)

### World Generation
- Multi-octave Perlin/Simplex noise
- Voronoi-based biome transitions
- Erosion, cave, and structure algorithms
- 10x chunk compression for storage efficiency

---

## 📦 Installation

### Prerequisites
- Python 3.9+ (3.11+ recommended)
- Modern C++ compiler (VS 2019+/GCC 9+)
- PostgreSQL 13+ (for production)
- Minimum 8GB RAM (16GB recommended)

### Quick Setup

```bash
git clone https://github.com/magi8101/mcpy.git
cd mcpy
# Windows
setup.bat
# Linux/macOS
chmod +x setup.sh
./setup.sh
```

### Manual Installation

```bash
git clone https://github.com/magi8101/mcpy.git
cd mcpy
python -m venv .venv
# Windows:
.venv\Scripts\activate
# Linux/macOS:
source .venv/bin/activate
pip install -r _requirements.txt
pip install -e ".[dev]"
pip install -e ".[ai]"  # Optional: Enable AI features
python check_dependencies.py
python setup.py build_ext --inplace
```

---

## 🚀 Running the Server

```bash
# Run using setup scripts
# Windows:
setup.bat run
# Linux/macOS:
./setup.sh run

# Directly from the command line
python -m mcpy.server
python -m mcpy.server --config custom_config.toml --world my_world
python -m mcpy.server --performance-mode --max-players 100
python -m mcpy.server --debug --log-level debug
```

#### Command Line Options

| Option                   | Description                             |
|--------------------------|-----------------------------------------|
| `--config PATH`          | Path to TOML config file                |
| `--world PATH`           | World directory                         |
| `--port NUMBER`          | Network port (default: 25565)           |
| `--max-players NUMBER`   | Max players (default: 20)               |
| `--view-distance NUMBER` | Chunk view distance (default: 10)       |
| `--performance-mode`     | Extra performance optimizations         |
| `--debug`                | Enable debug mode                       |
| `--log-level LEVEL`      | Set log level (default: info)           |
| `--backup`               | Enable automatic backups                |

---

## 🗄️ Database Configuration

### SQLite (Default)
```toml
[database]
type = "sqlite"
path = "world/mcpy.db"
journal_mode = "WAL"
synchronous = "NORMAL"
```

### PostgreSQL (Production)
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
echo = false
```

---

## 💾 Persistence Features

- **Transactional World Saving**
  ```python
  with session.begin():
      for chunk in dirty_chunks:
          session.add(ChunkModel.from_chunk(chunk))
  ```
- **Efficient Chunk Serialization**
  ```python
  chunk_data = np.savez_compressed(io_buffer,
                                  blocks=chunk.blocks,
                                  heightmap=chunk.heightmap,
                                  biomes=chunk.biomes)
  ```
- **Player Data Management**
  ```python
  player_model = PlayerModel(
      uuid=player.uuid,
      username=player.username,
      position=json.dumps([player.x, player.y, player.z]),
      inventory=pickle.dumps(player.inventory, protocol=5),
      stats=json.dumps(player.stats)
  )
  ```
- **Intelligent Auto-saving**: Tracks and saves only modified chunks/entities
- **Automated Backups**: Configurable intervals & retention

---

## 🧪 Development & Testing

```bash
pytest                  # Run full test suite
pytest tests/test_entity_system.py     # Entity system tests
python -m benchmarks.benchmark        # Benchmarks
python -m mcpy.profiling.profile_module world_engine  # Profile module
pytest --cov=mcpy --cov-report=html   # Test coverage report
```

### Performance Tuning Examples

- **Entity System**
  ```python
  entity_spatial_hash = {(int(e.x/16), int(e.z/16)): [] for e in entities}
  for entity in entities:
      entity_spatial_hash[(int(entity.x/16), int(entity.z/16))].append(entity)
  ```
- **World Engine**
  ```python
  with ThreadPoolExecutor(max_workers=os.cpu_count()) as executor:
      futures = [executor.submit(generate_chunk, x, z) for x, z in chunk_coords]
      chunks = [f.result() for f in futures]
  ```
- **Network Optimization**
  ```python
  cdef char* buffer = <char*>malloc(packet_size)
  memcpy(buffer, &packet_header, sizeof(packet_header))
  memcpy(buffer + sizeof(packet_header), packet_data, packet_data_size)
  ```

---

## 🔧 Advanced Features

### Plugin System

Add custom commands and behaviors easily:

```python
from mcpy.plugins import Plugin, event

class TeleportPlugin(Plugin):
    @event("player.command")
    def on_command(self, player, command, args):
        if command == "tp" and len(args) >= 1:
            target = self.server.get_player_by_name(args[0])
            if target:
                player.teleport(target.x, target.y, target.z)
                return True
        return False
```

### Real-time Monitoring

Integrated Prometheus/Grafana support:

```toml
[monitoring]
enabled = true
prometheus_port = 9090
metrics = ["tps", "memory_usage", "players_online", "chunks_loaded"]
```

### AI Entity Behaviors

Highly flexible AI system using behavior trees:

```python
class ZombieAI(MobAI):
    def setup_behaviors(self):
        self.behaviors = BehaviorTree(
            Selector([
                Sequence([
                    CheckPlayerNearby(radius=16),
                    PathfindToPlayer(),
                    AttackPlayer()
                ]),
                Sequence([
                    Wait(random.randint(20, 100)),
                    MoveToRandomPosition(radius=10)
                ])
            ])
        )
```

---

## 🗺️ Roadmap

### Short-Term
- [ ] Entity collision system
- [ ] Crafting & inventory management
- [ ] Basic combat mechanics
- [ ] World generation optimization

### Medium-Term
- [ ] Multi-world support & portals
- [ ] Custom block behaviors
- [ ] Enhanced mob AI
- [ ] In-game scripting API

### Long-Term
- [ ] Distributed server architecture
- [ ] Machine learning-driven mob AI
- [ ] Real-time ray-traced lighting
- [ ] Custom physics engine

---

## 🤝 Contributing

We welcome contributions! Please see our [Contributing Guide](CONTRIBUTING.md) to get started:

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to your branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

---

## 📄 License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for full details.

---
