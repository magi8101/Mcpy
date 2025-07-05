# MCPy: High-Performance Minecraft Server Engine

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Python 3.9+](https://img.shields.io/badge/python-3.9+-blue.svg)](https://www.python.org/downloads/)
[![Cython](https://img.shields.io/badge/Cython-0.29.34+-darkgreen.svg)](https://cython.org/)

---

**MCPy** is a next-generation, ultra-optimized Minecraft server engine powered by Python, Cython, and advanced scientific computing libraries. Our mission is to deliver exceptional performance and flexibility, making Minecraft server development both accessible and future-proof.

> **Note:**  
> MCPy is under active development and is **not yet feature-complete**. The codebase contains known errors and is unstable. We welcome your [bug reports and contributions](https://github.com/magi8101/Mcpy/blob/main/errorlog/error-1.md) to help us reach our goals faster!

---

## 🚧 Project Status

- The project is **incomplete** and contains known issues.
- Major features are under active development; the codebase is unstable.
- We highly value contributions and bug reports from the community.

---

## 🚀 Features at a Glance

- **Cython-Accelerated Core**: Event-driven server engine approaching C-level performance.
- **Scientific Computing Backbone**: Integrates NumPy, SciPy, and Polars for high-efficiency operations.
- **Zero-Overhead Networking**: Asynchronous, non-blocking, protocol-optimized networking.
- **Sophisticated Entity System**: Efficient, extensible entity management with advanced AI support.
- **Robust Persistence Layer**: Powered by PostgreSQL and SQLAlchemy ORM for reliable data storage.
- **Comprehensive Benchmarking**: Built-in performance analytics and profiling tools.
- **Extensible Plugin Framework**: Easily add server modifications.
- **Real-Time Monitoring**: Prometheus & Grafana integration for live metrics.

---

## 📐 Architecture Overview

MCPy is modular, with five high-performance core components:

1. **`server_core.pyx`**
   - Event-driven request handling
   - Adaptive, high-precision tick system
   - Dynamic worker thread pool management
   - Real-time performance profiling

2. **`world_engine.pyx`**
   - Procedural terrain generation with multi-octave noise and advanced biomes
   - Multi-threaded chunk generation & memory-efficient terrain storage

3. **`network_core.pyx`**
   - Zero-copy packet serialization and protocol-level compression
   - Robust connection pooling & DDoS mitigation

4. **`entity_system.pyx`**
   - Spatial hash-based entity tracking and multi-threaded physics
   - Modular AI behavior trees

5. **`persistence`**
   - SQLAlchemy ORM for PostgreSQL/SQLite
   - Efficient chunk serialization and transactional world state

---

## 📊 Performance Goals

| Metric                | Target Value                        |
|-----------------------|-------------------------------------|
| Scalability           | 20 TPS with 100+ concurrent players |
| Memory Usage          | <2 GB for 10,000 chunks             |
| Latency               | <50 ms per player action            |
| Reliability           | 100% test coverage for core modules |
| Throughput            | 10,000+ entity updates per tick     |

---

## ⚙️ Technical Highlights

### Cython & Performance

- Static typing (`cdef`) and aggressive compiler directives
- Direct NumPy buffer access and pointer arithmetic
- Multi-threaded parallelism via thread pools

### Entity System

- Hierarchical, component-based design
- O(1) spatial partitioning via custom memory pools
- Adaptive Level-of-Detail (LOD) entity management

### World Generation

- Multi-octave Perlin/Simplex noise
- Voronoi-based biome transitions
- Erosion, cave, and structure algorithms
- 10x chunk compression for storage efficiency

---

## 📦 Installation

### Prerequisites

- Python 3.9+ (3.11+ recommended)
- Modern C++ compiler (VS 2019+ / GCC 9+)
- PostgreSQL 13+ (for production)
- Minimum 8 GB RAM (16 GB recommended)

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
# Using setup scripts
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
- **Intelligent Auto-saving**: Only modified chunks/entities are saved
- **Automated Backups**: Configurable intervals & retention

---

## 🧪 Development & Testing

```bash
pytest                                # Run full test suite
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

Flexible, behavior-tree-driven AI:

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

**Short-Term**
- [ ] Entity collision system
- [ ] Crafting & inventory management
- [ ] Basic combat mechanics
- [ ] World generation optimization

**Medium-Term**
- [ ] Multi-world support & portals
- [ ] Custom block behaviors
- [ ] Enhanced mob AI
- [ ] In-game scripting API

**Long-Term**
- [ ] Distributed server architecture
- [ ] Machine learning-driven mob AI
- [ ] Real-time ray-traced lighting
- [ ] Custom physics engine

---

## 🤝 Contributing

We welcome your contributions! Please see our [Contributing Guide](CONTRIBUTING.md) to get started:

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to your branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

---

## 📄 License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.

---
