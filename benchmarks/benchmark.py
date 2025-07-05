#!/usr/bin/env python
"""
Benchmark suite for MCPy server.

This script runs a series of benchmarks to measure the performance of
critical components of the MCPy server.
"""

import argparse
import gc
import os
import sys
import time
import logging
from pathlib import Path
import numpy as np
import matplotlib.pyplot as plt
from contextlib import contextmanager

# Add the parent directory to the path so we can import mcpy
sys.path.insert(0, str(Path(__file__).parent.parent))

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("benchmarks")

# Import mcpy modules
try:
    from mcpy.core.world_engine import WorldEngine, TerrainGenerator, Chunk
    from mcpy.core.entity_system import EntitySystem, Entity
    from mcpy.core.network_core import NetworkBuffer, Packet
except ImportError:
    logger.error("Failed to import MCPy modules. Make sure you've built the Cython extensions.")
    sys.exit(1)

@contextmanager
def timer(name):
    """Context manager for timing code blocks."""
    gc.collect()  # Force garbage collection before timing
    start = time.perf_counter()
    yield
    end = time.perf_counter()
    logger.info(f"{name}: {end - start:.6f} seconds")

def benchmark_chunk_generation(world_path, count=100):
    """Benchmark chunk generation performance."""
    # Create a test world
    world = WorldEngine(world_path, view_distance=10)
    
    # Time chunk generation
    chunk_times = []
    for i in range(count):
        # Generate chunks in a spiral pattern
        chunk_x = (i // 4) * (1 if (i // 4) % 2 == 0 else -1)
        chunk_z = (i // 4 + i % 4) * (1 if (i // 4 + 1) % 2 == 0 else -1)
        
        start = time.perf_counter()
        chunk = world.get_chunk(chunk_x, chunk_z, True)
        end = time.perf_counter()
        
        chunk_times.append(end - start)
        
        if i % 10 == 0:
            logger.info(f"Generated {i} chunks, avg time: {np.mean(chunk_times):.6f}s")
    
    # Calculate statistics
    avg_time = np.mean(chunk_times)
    std_dev = np.std(chunk_times)
    min_time = np.min(chunk_times)
    max_time = np.max(chunk_times)
    median_time = np.median(chunk_times)
    p95_time = np.percentile(chunk_times, 95)
    
    # Log results
    logger.info("Chunk Generation Benchmark Results:")
    logger.info(f"  Chunks generated: {count}")
    logger.info(f"  Average time: {avg_time:.6f}s")
    logger.info(f"  Median time: {median_time:.6f}s")
    logger.info(f"  Standard deviation: {std_dev:.6f}s")
    logger.info(f"  Min time: {min_time:.6f}s")
    logger.info(f"  Max time: {max_time:.6f}s")
    logger.info(f"  95th percentile: {p95_time:.6f}s")
    logger.info(f"  Chunks per second: {1/avg_time:.2f}")
    
    # Plot histogram
    plt.figure(figsize=(10, 6))
    plt.hist(chunk_times, bins=20, alpha=0.7, color='blue')
    plt.axvline(avg_time, color='red', linestyle='dashed', linewidth=2, label=f'Mean: {avg_time:.6f}s')
    plt.axvline(median_time, color='green', linestyle='dashed', linewidth=2, label=f'Median: {median_time:.6f}s')
    plt.axvline(p95_time, color='orange', linestyle='dashed', linewidth=2, label=f'95th percentile: {p95_time:.6f}s')
    plt.xlabel('Time (seconds)')
    plt.ylabel('Frequency')
    plt.title('Chunk Generation Time Distribution')
    plt.legend()
    plt.grid(True, alpha=0.3)
    plt.savefig(os.path.join(world_path, 'chunk_generation_benchmark.png'))
    
    return {
        'avg_time': avg_time,
        'median_time': median_time,
        'std_dev': std_dev,
        'min_time': min_time,
        'max_time': max_time,
        'p95_time': p95_time,
        'chunks_per_second': 1/avg_time
    }

def benchmark_entity_updates(world_path, entity_count=1000, ticks=100):
    """Benchmark entity update performance."""
    # Create a test world
    world = WorldEngine(world_path, view_distance=10)
    
    # Create entity system
    entity_system = EntitySystem(world, max_entities=entity_count * 2)
    
    # Spawn entities
    logger.info(f"Spawning {entity_count} entities...")
    for i in range(entity_count):
        x = (i % 100) * 2
        z = (i // 100) * 2
        y = 64  # Spawn at ground level
        
        entity_system.spawn_entity(0, x, y, z)
    
    # Time entity updates
    tick_times = []
    for tick in range(ticks):
        start = time.perf_counter()
        entity_system.update(tick)
        end = time.perf_counter()
        
        tick_times.append(end - start)
        
        if tick % 10 == 0:
            logger.info(f"Processed {tick} ticks, avg time: {np.mean(tick_times):.6f}s")
    
    # Calculate statistics
    avg_time = np.mean(tick_times)
    std_dev = np.std(tick_times)
    min_time = np.min(tick_times)
    max_time = np.max(tick_times)
    median_time = np.median(tick_times)
    p95_time = np.percentile(tick_times, 95)
    entities_per_second = entity_count / avg_time
    
    # Log results
    logger.info("Entity Update Benchmark Results:")
    logger.info(f"  Entity count: {entity_count}")
    logger.info(f"  Ticks: {ticks}")
    logger.info(f"  Average time: {avg_time:.6f}s")
    logger.info(f"  Median time: {median_time:.6f}s")
    logger.info(f"  Standard deviation: {std_dev:.6f}s")
    logger.info(f"  Min time: {min_time:.6f}s")
    logger.info(f"  Max time: {max_time:.6f}s")
    logger.info(f"  95th percentile: {p95_time:.6f}s")
    logger.info(f"  Entities per second: {entities_per_second:.2f}")
    
    # Plot histogram
    plt.figure(figsize=(10, 6))
    plt.hist(tick_times, bins=20, alpha=0.7, color='green')
    plt.axvline(avg_time, color='red', linestyle='dashed', linewidth=2, label=f'Mean: {avg_time:.6f}s')
    plt.axvline(median_time, color='blue', linestyle='dashed', linewidth=2, label=f'Median: {median_time:.6f}s')
    plt.axvline(p95_time, color='orange', linestyle='dashed', linewidth=2, label=f'95th percentile: {p95_time:.6f}s')
    plt.xlabel('Time (seconds)')
    plt.ylabel('Frequency')
    plt.title('Entity Update Time Distribution')
    plt.legend()
    plt.grid(True, alpha=0.3)
    plt.savefig(os.path.join(world_path, 'entity_update_benchmark.png'))
    
    return {
        'avg_time': avg_time,
        'median_time': median_time,
        'std_dev': std_dev,
        'min_time': min_time,
        'max_time': max_time,
        'p95_time': p95_time,
        'entities_per_second': entities_per_second
    }

def benchmark_network_serialization(packet_count=10000):
    """Benchmark network packet serialization performance."""
    # Create a test packet
    packet_data = {
        'x': 100.5,
        'y': 64.0,
        'z': 200.5,
        'yaw': 45.0,
        'pitch': 30.0,
        'on_ground': True,
        'velocity': [0.1, 0.2, 0.3],
        'username': 'TestPlayer',
    }
    
    # Time packet serialization
    serialization_times = []
    for i in range(packet_count):
        # Create packet
        packet = Packet(0x08, 3)  # Play state, player position packet
        
        # Start timing
        start = time.perf_counter()
        
        # Write packet data
        packet.buffer.write_varint(i)  # Entity ID
        packet.buffer.write_double(packet_data['x'])
        packet.buffer.write_double(packet_data['y'])
        packet.buffer.write_double(packet_data['z'])
        packet.buffer.write_float(packet_data['yaw'])
        packet.buffer.write_float(packet_data['pitch'])
        packet.buffer.write_byte(1 if packet_data['on_ground'] else 0)
        packet.buffer.write_string(packet_data['username'])
        
        # Encode the packet
        encoded = packet.encode()
        
        # End timing
        end = time.perf_counter()
        serialization_times.append(end - start)
    
    # Calculate statistics
    avg_time = np.mean(serialization_times)
    std_dev = np.std(serialization_times)
    min_time = np.min(serialization_times)
    max_time = np.max(serialization_times)
    median_time = np.median(serialization_times)
    p95_time = np.percentile(serialization_times, 95)
    packets_per_second = 1 / avg_time
    
    # Log results
    logger.info("Network Serialization Benchmark Results:")
    logger.info(f"  Packets: {packet_count}")
    logger.info(f"  Average time: {avg_time:.9f}s")
    logger.info(f"  Median time: {median_time:.9f}s")
    logger.info(f"  Standard deviation: {std_dev:.9f}s")
    logger.info(f"  Min time: {min_time:.9f}s")
    logger.info(f"  Max time: {max_time:.9f}s")
    logger.info(f"  95th percentile: {p95_time:.9f}s")
    logger.info(f"  Packets per second: {packets_per_second:.2f}")
    
    # Plot histogram
    plt.figure(figsize=(10, 6))
    plt.hist(serialization_times, bins=20, alpha=0.7, color='purple')
    plt.axvline(avg_time, color='red', linestyle='dashed', linewidth=2, label=f'Mean: {avg_time:.9f}s')
    plt.axvline(median_time, color='blue', linestyle='dashed', linewidth=2, label=f'Median: {median_time:.9f}s')
    plt.axvline(p95_time, color='orange', linestyle='dashed', linewidth=2, label=f'95th percentile: {p95_time:.9f}s')
    plt.xlabel('Time (seconds)')
    plt.ylabel('Frequency')
    plt.title('Packet Serialization Time Distribution')
    plt.legend()
    plt.grid(True, alpha=0.3)
    plt.savefig('network_serialization_benchmark.png')
    
    return {
        'avg_time': avg_time,
        'median_time': median_time,
        'std_dev': std_dev,
        'min_time': min_time,
        'max_time': max_time,
        'p95_time': p95_time,
        'packets_per_second': packets_per_second
    }

def benchmark_block_operations(world_path, operations=100000):
    """Benchmark block get/set operations."""
    # Create a test world
    world = WorldEngine(world_path, view_distance=10)
    
    # Ensure a few chunks are generated
    for x in range(-2, 3):
        for z in range(-2, 3):
            world.get_chunk(x, z, True)
    
    # Time block get operations
    get_times = []
    for i in range(operations):
        x = (i % 100) - 50
        z = (i // 100 % 100) - 50
        y = 64 + (i // 10000)
        
        start = time.perf_counter()
        block = world.get_block(x, y, z)
        end = time.perf_counter()
        
        get_times.append(end - start)
        
        if i % 10000 == 0 and i > 0:
            logger.info(f"Performed {i} get operations, avg time: {np.mean(get_times[-10000:]):.9f}s")
    
    # Calculate statistics for get operations
    avg_get_time = np.mean(get_times)
    get_ops_per_second = 1 / avg_get_time
    
    # Time block set operations
    set_times = []
    for i in range(operations):
        x = (i % 100) - 50
        z = (i // 100 % 100) - 50
        y = 64 + (i // 10000)
        block_id = i % 20  # Use different block types
        
        start = time.perf_counter()
        world.set_block(x, y, z, block_id)
        end = time.perf_counter()
        
        set_times.append(end - start)
        
        if i % 10000 == 0 and i > 0:
            logger.info(f"Performed {i} set operations, avg time: {np.mean(set_times[-10000:]):.9f}s")
    
    # Calculate statistics for set operations
    avg_set_time = np.mean(set_times)
    set_ops_per_second = 1 / avg_set_time
    
    # Log results
    logger.info("Block Operations Benchmark Results:")
    logger.info(f"  Operations: {operations}")
    logger.info(f"  Average get time: {avg_get_time:.9f}s")
    logger.info(f"  Get operations per second: {get_ops_per_second:.2f}")
    logger.info(f"  Average set time: {avg_set_time:.9f}s")
    logger.info(f"  Set operations per second: {set_ops_per_second:.2f}")
    
    # Plot histogram
    plt.figure(figsize=(10, 6))
    plt.hist(get_times, bins=20, alpha=0.7, color='blue', label='Get operations')
    plt.hist(set_times, bins=20, alpha=0.7, color='red', label='Set operations')
    plt.axvline(avg_get_time, color='blue', linestyle='dashed', linewidth=2, label=f'Mean get: {avg_get_time:.9f}s')
    plt.axvline(avg_set_time, color='red', linestyle='dashed', linewidth=2, label=f'Mean set: {avg_set_time:.9f}s')
    plt.xlabel('Time (seconds)')
    plt.ylabel('Frequency')
    plt.title('Block Operation Time Distribution')
    plt.legend()
    plt.grid(True, alpha=0.3)
    plt.savefig(os.path.join(world_path, 'block_operations_benchmark.png'))
    
    return {
        'avg_get_time': avg_get_time,
        'get_ops_per_second': get_ops_per_second,
        'avg_set_time': avg_set_time,
        'set_ops_per_second': set_ops_per_second
    }

def benchmark_memory_usage(world_path):
    """Benchmark memory usage during world generation."""
    try:
        import psutil
        import matplotlib.pyplot as plt
    except ImportError:
        logger.error("psutil is required for memory benchmarking")
        return {}
        
    process = psutil.Process()
    initial_memory = process.memory_info().rss / 1024 / 1024  # MB
    
    # Create a test world
    world = WorldEngine(world_path, view_distance=10)
    
    # Generate chunks in a spiral pattern and track memory usage
    memory_usage = [initial_memory]
    chunk_counts = [0]
    
    for i in range(100):
        # Generate chunks in a spiral pattern
        for dx, dz in [(0, 1), (1, 0), (0, -1), (-1, 0)] * ((i // 4) + 1):
            chunk_x = dx * (i // 4)
            chunk_z = dz * (i // 4)
            
            world.get_chunk(chunk_x, chunk_z, True)
            
            # Track memory
            memory = process.memory_info().rss / 1024 / 1024  # MB
            memory_usage.append(memory)
            chunk_counts.append(len(world.chunks))
            
            if len(chunk_counts) % 10 == 0:
                logger.info(f"Generated {len(chunk_counts)-1} chunks, memory: {memory:.2f} MB")
    
    # Calculate statistics
    chunks_generated = len(chunk_counts) - 1
    initial_memory = memory_usage[0]
    final_memory = memory_usage[-1]
    memory_per_chunk = (final_memory - initial_memory) / chunks_generated
    
    # Log results
    logger.info("Memory Usage Benchmark Results:")
    logger.info(f"  Chunks generated: {chunks_generated}")
    logger.info(f"  Initial memory: {initial_memory:.2f} MB")
    logger.info(f"  Final memory: {final_memory:.2f} MB")
    logger.info(f"  Memory used: {final_memory - initial_memory:.2f} MB")
    logger.info(f"  Memory per chunk: {memory_per_chunk:.2f} MB")
    
    # Plot memory usage
    plt.figure(figsize=(10, 6))
    plt.plot(chunk_counts, memory_usage, marker='o', markersize=3)
    plt.xlabel('Chunks Generated')
    plt.ylabel('Memory Usage (MB)')
    plt.title('Memory Usage During Chunk Generation')
    plt.grid(True, alpha=0.3)
    plt.savefig(os.path.join(world_path, 'memory_usage_benchmark.png'))
    
    return {
        'initial_memory': initial_memory,
        'final_memory': final_memory,
        'memory_used': final_memory - initial_memory,
        'memory_per_chunk': memory_per_chunk,
        'chunks_generated': chunks_generated
    }

def main():
    """Run the benchmarks."""
    parser = argparse.ArgumentParser(description="MCPy Benchmarks")
    parser.add_argument("--world", type=str, default="benchmark_world", help="World directory for benchmarks")
    parser.add_argument("--chunk-count", type=int, default=100, help="Number of chunks to generate for benchmarks")
    parser.add_argument("--entity-count", type=int, default=1000, help="Number of entities for benchmarks")
    parser.add_argument("--operations", type=int, default=100000, help="Number of operations for benchmarks")
    parser.add_argument("--all", action="store_true", help="Run all benchmarks")
    parser.add_argument("--chunk", action="store_true", help="Run chunk generation benchmark")
    parser.add_argument("--entity", action="store_true", help="Run entity update benchmark")
    parser.add_argument("--network", action="store_true", help="Run network serialization benchmark")
    parser.add_argument("--block", action="store_true", help="Run block operations benchmark")
    parser.add_argument("--memory", action="store_true", help="Run memory usage benchmark")
    args = parser.parse_args()
    
    # Create benchmark world directory
    world_path = os.path.abspath(args.world)
    os.makedirs(world_path, exist_ok=True)
    
    # Determine which benchmarks to run
    run_all = args.all or not any([args.chunk, args.entity, args.network, args.block, args.memory])
    
    results = {}
    
    # Run benchmarks
    if run_all or args.chunk:
        with timer("Chunk generation benchmark"):
            results['chunk'] = benchmark_chunk_generation(world_path, args.chunk_count)
    
    if run_all or args.entity:
        with timer("Entity update benchmark"):
            results['entity'] = benchmark_entity_updates(world_path, args.entity_count)
    
    if run_all or args.network:
        with timer("Network serialization benchmark"):
            results['network'] = benchmark_network_serialization(args.operations)
    
    if run_all or args.block:
        with timer("Block operations benchmark"):
            results['block'] = benchmark_block_operations(world_path, args.operations)
    
    if run_all or args.memory:
        with timer("Memory usage benchmark"):
            results['memory'] = benchmark_memory_usage(world_path)
    
    # Save results
    import json
    with open(os.path.join(world_path, 'benchmark_results.json'), 'w') as f:
        json.dump(results, f, indent=2)
    
    # Generate summary plot
    if len(results) > 1:
        plt.figure(figsize=(12, 8))
        
        # Set up bar chart data
        benchmarks = list(results.keys())
        x_pos = np.arange(len(benchmarks))
        
        # Function to get metric from results with fallback
        def get_metric(section, key, fallback=0):
            if section in results and key in results[section]:
                return results[section][key]
            return fallback
        
        # Get primary metrics for each benchmark
        metrics = []
        labels = []
        
        if 'chunk' in results:
            metrics.append(get_metric('chunk', 'chunks_per_second'))
            labels.append('Chunks/s')
            
        if 'entity' in results:
            metrics.append(get_metric('entity', 'entities_per_second'))
            labels.append('Entities/s')
            
        if 'network' in results:
            metrics.append(get_metric('network', 'packets_per_second') / 1000)
            labels.append('Packets/s (x1000)')
            
        if 'block' in results:
            metrics.append(get_metric('block', 'get_ops_per_second') / 1000)
            labels.append('Block Gets/s (x1000)')
            metrics.append(get_metric('block', 'set_ops_per_second') / 1000)
            labels.append('Block Sets/s (x1000)')
            
        if 'memory' in results:
            metrics.append(get_metric('memory', 'memory_per_chunk'))
            labels.append('Memory/Chunk (MB)')
        
        # Create bar chart
        x_pos = np.arange(len(labels))
        plt.bar(x_pos, metrics, align='center', alpha=0.7)
        plt.xticks(x_pos, labels, rotation=45)
        plt.ylabel('Performance')
        plt.title('MCPy Benchmark Summary')
        plt.tight_layout()
        plt.savefig(os.path.join(world_path, 'benchmark_summary.png'))
    
    logger.info(f"Benchmarks complete, results saved to {world_path}")

if __name__ == "__main__":
    main()
