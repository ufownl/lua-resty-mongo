#include "lua-compat.h"

int lua_absindex(lua_State *L, int index) {
  if (index < 0 && index > LUA_REGISTRYINDEX) {
    index += lua_gettop(L) + 1;
  }
  return index;
}

int lua_geti(lua_State *L, int index, lua_Integer i) {
  index = lua_absindex(L, index);
  lua_pushinteger(L, i);
  lua_gettable(L, index);
  return lua_type(L, -1);
}

int lua_isinteger(lua_State *L, int index) {
  if (lua_type(L, index) == LUA_TNUMBER) {
    if (lua_tonumber(L, index) == lua_tointeger(L, index)) {
      return 1;
    }
  }
  return 0;
}
