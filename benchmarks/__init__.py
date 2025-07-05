"""Benchmarks package for MCPy.

This package contains performance benchmarking tools for the MCPy server,
measuring critical aspects like:
- World generation speed
- Entity update performance
- Chunk loading/unloading
- Network serialization
- Memory usage

To run all benchmarks:
    python -m benchmarks.benchmark

To run a specific benchmark:
    python -m benchmarks.benchmark --test world_gen
"""

import sys
from pathlib import Path

# Add the parent directory to Python path to ensure MCPy modules can be imported
sys.path.insert(0, str(Path(__file__).parent.parent))

# Available benchmarks
available_benchmarks = [
    'world_gen',
    'entity_update',
    'chunk_operations',
    'network',
    'memory_usage',
    'block_operations',
    'physics',
]
