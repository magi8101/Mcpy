from libc.stdint cimport int8_t, int16_t, int32_t, int64_t
from libc.stdint cimport uint8_t, uint16_t, uint32_t, uint64_t

cdef class EntityPhysics:
    cdef:
        object world_engine
        
    cpdef bint update_position(self, Entity entity, double delta_time) except? False
    cdef void _handle_collision(self, Entity entity, double new_x, double new_y, double new_z)
    cdef bint _check_collision(self, Entity entity, double x, double y, double z, double width, double height) except? True
    cdef bint _check_on_ground(self, Entity entity) except? False
    cdef bint _is_solid_block(self, uint8_t block_id) except? True

cdef class Entity:
    cdef:
        public uint64_t id
        public int entity_type
        public double x
        public double y
        public double z
        public float yaw
        public float pitch
        public double velocity_x
        public double velocity_y
        public double velocity_z
        public double width
        public double height
        public bint on_ground
        public bint affected_by_gravity
        public bint active
        public uint64_t last_active_time
        public dict data
        public int32_t chunk_x
        public int32_t chunk_z
        
    cpdef void update(self, uint64_t tick_number)
    cpdef dict to_data(self)
    cpdef void mark_active(self)

cdef class PlayerEntity(Entity):
    cdef:
        public str username
        public object uuid
        public int health
        public int food_level
        public float experience
        public int level
        public dict inventory
        public object connection
        
    cpdef void update(self, uint64_t tick_number)
    cpdef dict to_data(self)

cdef class MobEntity(Entity):
    cdef:
        public int health
        public int max_health
        public object ai_controller
        public bint hostile
        
    cpdef void update(self, uint64_t tick_number)
    cpdef dict to_data(self)
    cpdef void damage(self, int amount, Entity source=*)
    cpdef void heal(self, int amount)
    cpdef void on_death(self, Entity source=*)

cdef class HostileMobEntity(MobEntity):
    cdef:
        public double attack_damage
        public double attack_range
        public double detection_range
        public uint64_t attack_cooldown
        public uint64_t last_attack_time
    
    cpdef void update(self, uint64_t tick_number)
    cpdef dict to_data(self)
    cpdef bint can_attack(self, uint64_t current_tick) except? False
    cpdef void attack(self, Entity target, uint64_t current_tick)
    cdef double _get_attack_damage(self, int entity_type)

cdef class PassiveMobEntity(MobEntity):
    cdef:
        public uint64_t breeding_cooldown
        public uint64_t last_bred_time
        public bint is_baby
        public int growth_time
    
    cpdef void update(self, uint64_t tick_number)
    cpdef dict to_data(self)
    cpdef bint can_breed(self, uint64_t current_tick) except? False
    cpdef PassiveMobEntity breed(self, PassiveMobEntity partner, uint64_t current_tick)

cdef class ItemEntity(Entity):
    cdef:
        public int item_id
        public int count
        public dict metadata
        public uint64_t pickup_delay
        public uint64_t despawn_time
        
    cpdef void update(self, uint64_t tick_number)
    cpdef dict to_data(self)

cdef class ProjectileEntity(Entity):
    cdef:
        public Entity shooter
        public double damage
        public uint64_t creation_time
        public uint64_t max_age
        
    cpdef void update(self, uint64_t tick_number)
    cpdef dict to_data(self)

cdef class VehicleEntity(Entity):
    cdef:
        public list passengers
        public double max_speed
        public double acceleration
        public double deceleration
        public bint is_powered
    
    cpdef void update(self, uint64_t tick_number)
    cpdef dict to_data(self)
    cpdef bint add_passenger(self, Entity entity) except? False
    cpdef bint remove_passenger(self, Entity entity) except? False

cdef class FallingBlockEntity(Entity):
    cdef:
        public uint8_t block_id
        public uint8_t data_value
        public uint64_t time_existed
        public bint can_hurt_entities
    
    cpdef void update(self, uint64_t tick_number)
    cpdef dict to_data(self)

cdef class EntityFactory:
    cdef:
        public object world_engine
    
    cpdef Entity create_entity(self, int entity_type, double x, double y, double z, dict additional_data=*)
    cdef void _configure_mob_properties(self, MobEntity mob, int entity_type, dict additional_data)
    cdef int _get_mob_health(self, int entity_type)

cdef class EntityTracker:
    cdef:
        public dict entities
        public dict entities_by_type
        public dict entities_by_chunk
        public int max_entities
        public object entity_lock
    
    cpdef void add_entity(self, Entity entity) except *
    cpdef void remove_entity(self, uint64_t entity_id) except *
    cpdef void update_entity_chunk(self, Entity entity) except *
    cpdef Entity get_entity(self, uint64_t entity_id) except *
    cpdef list get_entities_of_type(self, int entity_type)
    cpdef list get_entities_in_chunks(self, list chunk_coords)
    cpdef list get_entities_in_range(self, double x, double y, double z, double radius)
    cpdef int get_entity_count(self)
    cpdef int get_entity_count_of_type(self, int entity_type)
    cpdef bint entity_exists(self, uint64_t entity_id) except? -1

cdef class EntitySystem:
    cdef:
        public object world_engine
        public dict players
        public EntityPhysics physics
        public EntityFactory factory
        public EntityTracker tracker
        public int max_entities
        
    cpdef void update(self, uint64_t tick_number)
    cpdef Entity spawn_entity(self, int entity_type, double x, double y, double z, dict additional_data=*)
    cpdef PlayerEntity add_player(self, str username, object uuid_obj, double x, double y, double z)
    cpdef void remove_player(self, uint64_t player_id)
    cpdef list get_entities_in_range(self, double x, double z, double radius)
    cpdef list get_entities_in_chunks(self, list chunk_coords)
    cpdef Entity get_entity_by_id(self, uint64_t entity_id)
    cpdef PlayerEntity get_player_by_name(self, str username)
    cpdef int get_active_entity_count(self)
    cpdef list get_entities_of_type(self, int entity_type)
    cpdef void cleanup(self)
