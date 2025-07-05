from libc.stdint cimport int8_t, int16_t, int32_t, int64_t
from libc.stdint cimport uint8_t, uint16_t, uint32_t, uint64_t

cdef class ServerConfiguration:
    cdef:
        public str host
        public int port
        public str world_path
        public int max_players
        public int view_distance
        public bint online_mode
        public bint whitelist_enabled
        public object config_data

cdef class PerformanceMetrics:
    cdef:
        public double last_tick_duration
        public double avg_tick_duration
        public double min_tick_duration
        public double max_tick_duration
        public uint64_t tick_count
        public double last_memory_usage
        public double avg_memory_usage
        public list tick_history
        public uint64_t start_time
        
    cpdef void record_tick(self, double duration)
    cpdef void record_memory_usage(self, double memory_mb)
    cpdef dict get_metrics(self)

cdef class ServerInstance:
    cdef:
        public ServerConfiguration config
        public object world_engine
        public object network_manager
        public object entity_system
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
        
    cdef void _process_tick(self, uint64_t tick_number)
    cdef void _process_players(self, uint64_t tick_number)
    cdef void _process_world_events(self, uint64_t tick_number)
