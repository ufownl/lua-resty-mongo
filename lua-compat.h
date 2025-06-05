#ifndef RMONGO_LUA_COMPAT
#define RMONGO_LUA_COMPAT

#ifdef __cplusplus
extern "C" {
#endif

#include <lua.h>
#include <lauxlib.h>

#define lua_setuservalue(L, i) (luaL_checktype((L), -1, LUA_TTABLE), lua_setfenv((L), (i)))
#define lua_getuservalue(L, i) (lua_getfenv((L), (i)), lua_type((L), -1))
#define lua_rawget(L, i) (lua_rawget((L), (i)), lua_type((L), -1))

int lua_absindex(lua_State *L, int index);
int lua_geti(lua_State *L, int index, lua_Integer i);
int lua_isinteger(lua_State *L, int index);

#ifdef __cplusplus
}
#endif

#endif  // RMONGO_LUA_COMPAT
