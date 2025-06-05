find_package(LuaJIT REQUIRED)
get_filename_component(LUA_LIBRARY_DIR ${LUA_LIBRARY} PATH)

add_library(bson MODULE lua-bson.c lua-compat.c)
target_include_directories(bson PRIVATE ${LUA_INCLUDE_DIR})
set_target_properties(bson PROPERTIES
  PREFIX ""
  SUFFIX ".so"
  INSTALL_RPATH ${LUA_LIBRARY_DIR}
)

add_library(mongo MODULE lua-mongo.c)
target_include_directories(mongo PRIVATE ${LUA_INCLUDE_DIR})
set_target_properties(mongo PROPERTIES
  PREFIX ""
  SUFFIX ".so"
  INSTALL_RPATH ${LUA_LIBRARY_DIR}
)

set(LUA_MODULE_DIR "${LUA_LIBRARY_DIR}/lua/5.1")
install(TARGETS bson DESTINATION ${LUA_MODULE_DIR})
install(TARGETS mongo DESTINATION ${LUA_MODULE_DIR})
