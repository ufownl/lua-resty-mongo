local t, b
local bson = require "bson"

local sub = bson.encode_order( "hello", 1, "world", 2 )

do
  -- check decode encode_order
  local d = bson.decode(sub)
  assert(d.hello == 1 )
  assert(d.world == 2 )
end

local function tbl_next(...)
  print("--- next.a ", ...)
  local k, v = next(...)
  print("--- next.b ", k, " ", v)
  return k, v
end

local function tbl_pairs(obj)
  return tbl_next, obj.__data, nil
end

local obj_a = {
  __data = {
    ["1"] = 2,
    ["3"] = 4,
    ["5"] = 6,
  }
}

setmetatable(
  obj_a,
  {
    __index = obj_a.__data,
    __pairs = tbl_pairs,
  }
)

local obj_b = {
  __data = {
    ["7"] = 8,
    ["9"] = 10,
    ["11"] = obj_a,
  }
}

setmetatable(
  obj_b,
  {
    __index = obj_b.__data,
    __pairs = tbl_pairs,
  }
)

local metaarray = setmetatable({ n = 5 }, {
  __len = function(self) return self.n end,
  __index = function(self, idx) return tostring(idx) end,
})

b = bson.encode {
  a = 1,
  b = true,
  c = bson.null,
  d = { 1,2,3,4 },
  e = bson.binary "hello",
  f = bson.regex ("*","i"),
  g = bson.regex "hello",
  h = bson.date (ngx.now()),
  i = bson.timestamp(ngx.time()),
  j = bson.objectid(),
  k = { a = false, b = true },
  l = {},
  m = bson.minkey,
  n = bson.maxkey,
  o = sub,
  p = 2^32-1,
  q = obj_b,
  r = metaarray,
  pi = 3.1415926
}

print "\n[before replace]"
t = b:decode()

for k, v in pairs(t) do
  print(k, " " , bson.type(v))
end

for k,v in ipairs(t.r) do
  print(k, " ",v)
end

ngx.sleep(1)

b:makeindex()
b.a = 2
b.b = false
b.h = bson.date(ngx.now())
b.i = bson.timestamp(ngx.time())
b.j = bson.objectid()

print "\n[after replace]"
t = b:decode()

for k, v in pairs(t) do
  print(k, " " , bson.type(v))
end

for k,v in ipairs(t.r) do
  print(k, " ",v)
end

print()
print("o.hello", " ", bson.type(t.o.hello))
