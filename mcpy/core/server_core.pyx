# cython: language_level=3, boundscheck=False, wraparound=False, cdivision=True
"""
Core server implementation for MCPy.

This module handles the main server logic including:
- Server initialization and lifecycle management
- Player session management
- World loading and coordination
- Tick system for simulation updates
"""

# Import from standard libraries
from libc.stdlib cimport malloc, free
from libc.string cimport memset, memcpy
from cpython cimport PyObject, Py_INCREF, Py_DECREF
from cpython.ref cimport PyObject
from libc.stdint cimport int8_t, int16_t, int32_t, int64_t
from libc.stdint cimport uint8_t, uint16_t, uint32_t, uint64_t
from libc.time cimport time_t, time
from libc.math cimport sqrt, floor, ceil

# NumPy imports
import numpy as np
cimport numpy as np
np.import_array()

# Python imports
import asyncio
import logging
import os
import sys
import time as py_time
from pathlib import Path
from typing import Dict, List, Optional, Set, Tuple, Any, Union

# Import core modules
from mcpy.core.world_engine cimport WorldEngine
from mcpy.core.network_core cimport NetworkManager
from mcpy.core.entity_system cimport EntitySystem

# Import persistence module (optional)
try:
    from mcpy.persistence.integration import PersistenceManager
    HAS_PERSISTENCE = True
except ImportError:
    HAS_PERSISTENCE = False
    logging.getLogger("mcpy.server_core").warning("Persistence module not available. Data will not be saved.")

# Define constants
DEF TICK_RATE = 20  # Server ticks per second
DEF MAX_PLAYERS = 1000
DEF DEFAULT_VIEW_DISTANCE = 10
DEF MAX_VIEW_DISTANCE = 32
DEF MIN_VIEW_DISTANCE = 2
DEF MAX_SIMULATION_DISTANCE = 128

# Logger
logger = logging.getLogger("mcpy.server_core")

# Performance metrics
cdef class PerformanceMetrics:
        public double last_tick_duration
        public double avg_tick_duration
        public double min_tick_duration
        public double max_tick_duration
        public uint64_t tick_count
        public double last_memory_usage
        public double avg_memory_usage
        public list tick_history
        public uint64_t start_time
        
    def __cinit__(self):
        self.last_tick_duration = 0.0
        self.avg_tick_duration = 0.0
        self.min_tick_duration = 1000.0
        self.max_tick_duration = 0.0
        self.tick_count = 0
        self.last_memory_usage = 0.0
        self.avg_memory_usage = 0.0
        self.tick_history = []
        self.start_time = <uint64_t>time(NULL)
    
    cpdef void record_tick(self, double duration):
        self.last_tick_duration = duration
        self.tick_count += 1
        
        # Update min/max
        if duration < self.min_tick_duration:
            self.min_tick_duration = duration
        if duration > self.max_tick_duration:
            self.max_tick_duration = duration
        
        # Update moving average (keep last 100 ticks)
        self.tick_history.append(duration)
        if len(self.tick_history) > 100:
            self.tick_history.pop(0)
        
        # Calculate average
        self.avg_tick_duration = sum(self.tick_history) / len(self.tick_history)
        
    cpdef void record_memory_usage(self, double memory_mb):
        self.last_memory_usage = memory_mb
        # Simple exponential moving average for memory usage
        if self.avg_memory_usage == 0.0:
            self.avg_memory_usage = memory_mb
        else:
            self.avg_memory_usage = 0.9 * self.avg_memory_usage + 0.1 * memory_mb

    cpdef dict get_metrics(self):
        return {
            "tick_rate": TICK_RATE,
            "current_tick_ms": self.last_tick_duration * 1000,
            "avg_tick_ms": self.avg_tick_duration * 1000,
            "min_tick_ms": self.min_tick_duration * 1000,
            "max_tick_ms": self.max_tick_duration * 1000,
            "memory_usage_mb": self.last_memory_usage,
            "avg_memory_mb": self.avg_memory_usage,
            "uptime_seconds": <uint64_t>time(NULL) - self.start_time,
            "tick_count": self.tick_count,
            "tps": min(TICK_RATE, 1.0 / max(self.avg_tick_duration, 1e-6))
        }
        
cdef class ServerConfiguration:
        public str host
        public int port
        public str world_path
        public int max_players
        public int view_distance
        public bint online_mode
        public bint whitelist_enabled
        public object config_data
        
    def __cinit__(self, str host, int port, str world_path, object config_data):
        self.host = host
        self.port = port
        self.world_path = world_path
        self.config_data = config_data
        
        # Extract settings from config data with defaults
        self.max_players = config_data.get("server", {}).get("max_players", MAX_PLAYERS)
        self.view_distance = config_data.get("server", {}).get("view_distance", DEFAULT_VIEW_DISTANCE)
        self.online_mode = config_data.get("server", {}).get("online_mode", True)
        self.whitelist_enabled = config_data.get("server", {}).get("whitelist", False)

        # Validate settings
        if self.view_distance < MIN_VIEW_DISTANCE:
            self.view_distance = MIN_VIEW_DISTANCE
            logger.warning(f"View distance too small, setting to minimum ({MIN_VIEW_DISTANCE})")
        elif self.view_distance > MAX_VIEW_DISTANCE:
            self.view_distance = MAX_VIEW_DISTANCE
            logger.warning(f"View distance too large, setting to maximum ({MAX_VIEW_DISTANCE})")
            
        if self.max_players <= 0:
            self.max_players = MAX_PLAYERS
            logger.warning(f"Invalid max_players, using default ({MAX_PLAYERS})")

cdef class ServerInstance:
    """Main server instance that coordinates all game systems."""
    cdef:
        public ServerConfiguration config
        public WorldEngine world_engine
        public NetworkManager network_manager
        public EntitySystem entity_system
        public PerformanceMetrics metrics
        public object event_loop
        public object tick_task
        public bint running
        public uint64_t current_tick
        public double tick_interval
        public double next_tick_time
        public object player_sessions
        public object prometheus_server
        public object admin_interface
        public object plugin_manager
        public object persistence_manager  # New: persistence manager for database operations
        
    def __cinit__(self, str host, int port, str world_path, dict config):
        """Initialize the server instance with configuration."""
        self.config = ServerConfiguration(host, port, world_path, config)
        self.metrics = PerformanceMetrics()
        self.running = False
        self.current_tick = 0
        self.tick_interval = 1.0 / TICK_RATE
        self.next_tick_time = 0.0
        self.player_sessions = {}
        
        # Initialize prometheus monitoring if configured
        if config.get("monitoring", {}).get("enabled", False):
            self._setup_monitoring()
            
        logger.info(f"Server instance created with config: {host}:{port}, world: {world_path}")
        
    def __dealloc__(self):
        """Clean up resources."""
        self.stop()
            
    def _setup_monitoring(self):
        """Set up Prometheus monitoring."""
        try:
            from prometheus_client import start_http_server, Gauge, Counter
            
            # Start Prometheus server
            prometheus_port = self.config.config_data.get("monitoring", {}).get("port", 9090)
            start_http_server(prometheus_port)
            logger.info(f"Prometheus monitoring started on port {prometheus_port}")
            
            # Define metrics
            self.prometheus_metrics = {
                "tick_duration": Gauge("mcpy_tick_duration_seconds", "Duration of the last server tick in seconds"),
                "memory_usage": Gauge("mcpy_memory_usage_bytes", "Current memory usage in bytes"),
                "player_count": Gauge("mcpy_player_count", "Number of connected players"),
                "chunks_loaded": Gauge("mcpy_chunks_loaded", "Number of loaded chunks"),
                "entities_active": Gauge("mcpy_entities_active", "Number of active entities"),
                "tps": Gauge("mcpy_tps", "Current server ticks per second"),
            }
            
        except ImportError:
            logger.warning("prometheus_client not found, monitoring disabled")
            self.prometheus_server = None
    
    def _update_monitoring(self):
        """Update Prometheus metrics."""
        if hasattr(self, "prometheus_metrics"):
            metrics = self.metrics.get_metrics()
            self.prometheus_metrics["tick_duration"].set(metrics["current_tick_ms"] / 1000.0)
            self.prometheus_metrics["tps"].set(metrics["tps"])
            self.prometheus_metrics["player_count"].set(len(self.player_sessions))
            
            # Get entity count from entity system
            if self.entity_system is not None:
                entity_count = self.entity_system.get_active_entity_count()
                self.prometheus_metrics["entities_active"].set(entity_count)
                
            # Get chunk count from world engine
            if self.world_engine is not None:
                chunk_count = self.world_engine.get_loaded_chunk_count()
                self.prometheus_metrics["chunks_loaded"].set(chunk_count)
                
            # Update memory usage
            try:
                import psutil
                process = psutil.Process()
                memory_info = process.memory_info()
                memory_mb = memory_info.rss / (1024 * 1024)
                self.metrics.record_memory_usage(memory_mb)
                self.prometheus_metrics["memory_usage"].set(memory_info.rss)
            except ImportError:
                logger.debug("psutil not available for memory monitoring")
                
    async def _tick_loop(self):
        """Main server tick loop."""
        logger.info(f"Server tick loop started at {TICK_RATE} ticks per second")
        
        while self.running:
            tick_start = py_time.time()
            
            try:
                # Process this tick
                self._process_tick(self.current_tick)
                self.current_tick += 1
                
                # Measure tick duration
                tick_end = py_time.time()
                tick_duration = tick_end - tick_start
                self.metrics.record_tick(tick_duration)
                
                # Update monitoring
                if self.current_tick % 20 == 0:  # Update every second
                    self._update_monitoring()
                    
                # Log performance issues
                if tick_duration > self.tick_interval:
                    lag_ms = (tick_duration - self.tick_interval) * 1000
                    if lag_ms > 50:  # Only log significant lag (> 50ms)
                        logger.warning(f"Server lagging by {lag_ms:.2f}ms on tick {self.current_tick}")
                
                # Wait for next tick
                next_tick = tick_start + self.tick_interval
                sleep_time = max(0, next_tick - py_time.time())
                
                if sleep_time > 0:
                    await asyncio.sleep(sleep_time)
            
            except Exception as e:
                logger.error(f"Error in tick loop: {e}", exc_info=True)
                # Don't crash the server on tick errors, try to continue
    
    cdef void _process_tick(self, uint64_t tick_number):
        """Process a single server tick."""
        # Process network events first
        if self.network_manager is not None:
            self.network_manager.process_network_events()
            
        # Update all entities
        if self.entity_system is not None:
            self.entity_system.update(tick_number)
            
        # Update world (chunks, blocks, etc.)
        if self.world_engine is not None:
            self.world_engine.update(tick_number)
            
        # Process player actions and updates
        self._process_players(tick_number)
        
        # World events (weather, time, etc.)
        self._process_world_events(tick_number)
        
        # Persistence: Auto-save world data if enabled
        if hasattr(self, "persistence_manager") and self.persistence_manager is not None:
            try:
                # Check if it's time for auto-save
                self.persistence_manager.check_auto_save(self.world_engine, self.entity_system)
            except Exception as e:
                logger.error(f"Error during auto-save: {e}", exc_info=True)
        
    cdef void _process_players(self, uint64_t tick_number):
        """Process player updates."""
        # This would be implemented based on player session objects
        pass
        
    cdef void _process_world_events(self, uint64_t tick_number):
        """Process world events like time, weather, etc."""
        # This would be implemented based on world engine
        pass
    
    def start(self):
        """Start the server."""
        if self.running:
            logger.warning("Server is already running")
            return
            
        logger.info("Starting server...")
        
        try:
            # Create event loop
            self.event_loop = asyncio.new_event_loop()
            asyncio.set_event_loop(self.event_loop)
            
            # Initialize subsystems
            self._initialize_systems()
            
            # Start the server
            self.running = True
            self.current_tick = 0
            self.next_tick_time = py_time.time()
            
            # Start tick loop
            self.tick_task = self.event_loop.create_task(self._tick_loop())
            
            # Run the event loop
            self.event_loop.run_forever()
        
        except Exception as e:
            logger.critical(f"Failed to start server: {e}", exc_info=True)
            self.stop()
            raise
            
    def stop(self):
        """Stop the server."""
        if not self.running:
            return
            
        logger.info("Stopping server...")
        self.running = False
        
        # Stop tick loop
        if hasattr(self, "tick_task") and self.tick_task is not None:
            self.tick_task.cancel()
            
        # Stop event loop
        if hasattr(self, "event_loop") and self.event_loop is not None:
            self.event_loop.stop()
            
        # Clean up subsystems
        self._cleanup_systems()
        
        logger.info("Server stopped")
        
    def _initialize_systems(self):
        """Initialize all server subsystems."""
        # Initialize world engine
        self.world_engine = WorldEngine(
            world_path=self.config.world_path,
            view_distance=self.config.view_distance,
        )
        
        # Initialize entity system
        self.entity_system = EntitySystem(
            world_engine=self.world_engine,
            max_entities=10000,
        )
        
        # Initialize network manager
        self.network_manager = NetworkManager(
            host=self.config.host,
            port=self.config.port,
            max_connections=self.config.max_players,
            server_instance=self,
        )
        
        # Initialize plugin system if enabled
        if self.config.config_data.get("plugins", {}).get("enabled", False):
            self._initialize_plugins()
            
    def _cleanup_systems(self):
        """Clean up all server subsystems."""
        # Clean up network manager
        if self.network_manager is not None:
            self.network_manager.shutdown()
        
        # Persistence: Save all data before shutting down
        if hasattr(self, "persistence_manager") and self.persistence_manager is not None:
            logger.info("Saving all world and entity data to database...")
            try:
                self.persistence_manager.save_state(self.world_engine, self.entity_system)
                logger.info("Database save completed successfully")
            except Exception as e:
                logger.error(f"Error saving data to database: {e}", exc_info=True)
            
        # Clean up world engine (save chunks, etc.)
        if self.world_engine is not None:
            self.world_engine.save_all()
            
        # Clean up entity system
        if self.entity_system is not None:
            self.entity_system.cleanup()
            
    def _initialize_plugins(self):
        """Initialize the plugin system."""
        # This would be implemented based on plugin system
        pass
        
    def get_status(self) -> dict:
        """Get server status information."""
        status = {
            "running": self.running,
            "current_tick": self.current_tick,
            "player_count": len(self.player_sessions),
            "max_players": self.config.max_players,
            "metrics": self.metrics.get_metrics(),
        }
        
        if self.world_engine is not None:
            status["world"] = self.world_engine.get_world_info()
            
        return status
