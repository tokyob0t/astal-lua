# GTK4 Examples

These examples replaces lgi requires with [LuaGObject](https://github.com/vtrlx/LuaGObject).

> [!TIP]
> To use GTK4 Layer Shell, you need to preload the library, e.g.:
>
> ```
> LD_PRELOAD=libgtk4-layer-shell.so lua init.lua
> ```
>
> This can be avoided when using LuaJIT or another Lua implementation with FFI support,
> by loading the library with dlopen before making any lgi calls 
> ```lua
> local ffi = require('ffi')
>
> local RTLD = { LAZY = 1, NOW = 2, GLOBAL = 0x100 }
>
> ffi.cdef('void* dlopen(const char* filename, int flag);')
>
> ffi.C.dlopen('libgtk4-layer-shell.so', RTLD.LAZY)
> ```
