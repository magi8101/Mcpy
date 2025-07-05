## Cython Compilation Errors in `mcpy/core/entity_system.pyx`

The following Cython compilation errors are currently being encountered while building the project. This issue is actively being worked on, and contributions from the community are welcome to help resolve these errors.

---

### Full Error Output

```
Compiling mcpy/core/entity_system.pyx because it changed.
[1/1] Cythonizing mcpy/core/entity_system.pyx
warning: mcpy\core\entity_system.pxd:156:27: noexcept clause is ignored for function returning Python object

Error compiling Cython file:
------------------------------------------------------------
...
        return player

cdef class MobEntity(Entity):
    """Base class for mobile entities with AI."""
    cdef:
        public int health
                   ^
------------------------------------------------------------

mcpy\core\entity_system.pyx:401:19: C attributes cannot be added in implementation part of extension type defined in a pxd

Error compiling Cython file:
------------------------------------------------------------
...
        public int health
        public int max_health
                   ^
------------------------------------------------------------

mcpy\core\entity_system.pyx:402:19: C attributes cannot be added in implementation part of extension type defined in a pxd

Error compiling Cython file:
------------------------------------------------------------
...
        public int health
        public int max_health
        public object ai_controller
                      ^
------------------------------------------------------------

mcpy\core\entity_system.pyx:403:22: C attributes cannot be added in implementation part of extension type defined in a pxd

Error compiling Cython file:
------------------------------------------------------------
...
        public int health
        public int max_health
        public object ai_controller
        public bint hostile
                    ^
------------------------------------------------------------

mcpy\core\entity_system.pyx:404:20: C attributes cannot be added in implementation part of extension type defined in a pxd

Error compiling Cython file:
------------------------------------------------------------
...
    cpdef void update(self, uint64_t tick_number)
    cpdef dict to_data(self)
    cpdef bint can_attack(self, uint64_t current_tick) except? False
                         ^
------------------------------------------------------------

mcpy\core\entity_system.pxd:77:25: C method 'can_attack' is declared but not defined

Error compiling Cython file:
------------------------------------------------------------
...
    cpdef bint can_attack(self, uint64_t current_tick) except? False
    cpdef void attack(self, Entity target, uint64_t current_tick)
                     ^
------------------------------------------------------------

mcpy\core\entity_system.pxd:78:21: C method 'attack' is declared but not defined

Error compiling Cython file:
------------------------------------------------------------
...
    cpdef void attack(self, Entity target, uint64_t current_tick)
    cdef double _get_attack_damage(self, int entity_type)
                                  ^
------------------------------------------------------------

mcpy\core\entity_system.pxd:79:34: C method '_get_attack_damage' is declared but not defined

Error compiling Cython file:
------------------------------------------------------------
...
    cpdef dict to_data(self)
    cpdef bint can_breed(self, uint64_t current_tick) except? False
                        ^
------------------------------------------------------------

mcpy\core\entity_system.pxd:90:24: C method 'can_breed' is declared but not defined

Error compiling Cython file:
------------------------------------------------------------
...
    cpdef bint can_breed(self, uint64_t current_tick) except? False
    cpdef PassiveMobEntity breed(self, PassiveMobEntity partner, uint64_t current_tick)
                                ^
------------------------------------------------------------

mcpy\core\entity_system.pxd:91:32: C method 'breed' is declared but not defined

Error compiling Cython file:
------------------------------------------------------------
...
    cpdef dict to_data(self)
    cpdef bint add_passenger(self, Entity entity) except? False
                            ^
------------------------------------------------------------

mcpy\core\entity_system.pxd:124:28: C method 'add_passenger' is declared but not defined

Error compiling Cython file:
------------------------------------------------------------
...
    cpdef bint add_passenger(self, Entity entity) except? False
    cpdef bint remove_passenger(self, Entity entity) except? False
                               ^
------------------------------------------------------------

mcpy\core\entity_system.pxd:125:31: C method 'remove_passenger' is declared but not defined

Error compiling Cython file:
------------------------------------------------------------
...
    cpdef Entity create_entity(self, int entity_type, double x, double y, double z, dict additional_data=*)
                              ^
------------------------------------------------------------

mcpy\core\entity_system.pxd:141:30: C method 'create_entity' is declared but not defined

Error compiling Cython file:
------------------------------------------------------------
...
    cpdef Entity create_entity(self, int entity_type, double x, double y, double z, dict additional_data=*)
    cdef void _configure_mob_properties(self, MobEntity mob, int entity_type, dict additional_data) 
                                       ^
------------------------------------------------------------

mcpy\core\entity_system.pxd:142:39: C method '_configure_mob_properties' is declared but not defined

Error compiling Cython file:
------------------------------------------------------------
...
    cdef void _configure_mob_properties(self, MobEntity mob, int entity_type, dict additional_data) 
    cdef int _get_mob_health(self, int entity_type)
                            ^
------------------------------------------------------------

mcpy\core\entity_system.pxd:143:28: C method '_get_mob_health' is declared but not defined
```

---

### Status

We are actively working to resolve these Cython compilation errors in the codebase.  
**Contributions and suggestions from the community are highly encouraged.**  
If you have insights, fixes, or recommendations, please consider submitting a pull request or opening a discussion. Review of the error log and collaborative debugging are much appreciated.

#### Current Administrators Managing This Issue

- @magi8101

---

*Thank you for your attention and support towards improving this project.*