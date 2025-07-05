from libc.stdint cimport int8_t, int16_t, int32_t, int64_t
from libc.stdint cimport uint8_t, uint16_t, uint32_t, uint64_t

cdef class NetworkBuffer:
    cdef:
        unsigned char* buffer
        size_t size
        size_t capacity
        size_t position
        
    cdef int ensure_capacity(self, size_t additional) except -1
    cdef int write_bytes(self, const unsigned char* data, size_t length) except -1
    cdef int write_byte(self, uint8_t value) except -1
    cdef int write_int(self, int32_t value) except -1
    cdef int write_short(self, int16_t value) except -1
    cdef int write_varint(self, int32_t value) except -1
    cdef int write_long(self, int64_t value) except -1
    cdef int write_string(self, str string) except -1
    cdef uint8_t read_byte(self) except? 0
    cdef int16_t read_short(self) except? 0
    cdef int32_t read_int(self) except? 0
    cdef int32_t read_varint(self) except? 0
    cdef int64_t read_long(self) except? 0
    cdef str read_string(self) except *
    cpdef bytes to_bytes(self)
    cpdef void reset(self)
    cpdef size_t get_size(self)
    cpdef size_t get_position(self)
    cpdef void set_position(self, size_t position)

cdef class Packet:
    cdef:
        public int id
        public int state
        public NetworkBuffer buffer
        
    cpdef bytes encode(self)

cdef class ClientConnection:
    cdef:
        public object reader
        public object writer
        public int state
        public str address
        public int port
        public bint encrypted
        public bint compressed
        public str username
        public bytes verify_token
        public object uuid
        public object manager
        public uint64_t last_keepalive
        public int ping_ms
        public bint authenticated
        public object player
        public dict metadata
        
    async def read_varint_bytes(self, uint8_t first_byte)

cdef class NetworkManager:
    cdef:
        public str host
        public int port
        public int max_connections
        public object server_instance
        public list connections
        public object server
        public object event_loop
        public bint running
