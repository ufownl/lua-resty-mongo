local mongo = require "resty.mongo"
local bson = require "bson"

local host, port, db_name, username, password = ...
if port then
	port = math.tointeger(port)
end

host = '127.0.0.1'
port = 27017
username = "admin"
password = 123456
db_name = "test"
-- print(host, port, db_name, username, password)

local function _create_client()
	return assert(mongo.client(
		{
			host = host, port = port,
			username = username, password = password,
			authdb = "admin"
		}
	))
end

local function test_auth()
	local ok, err, ret
	local c = mongo.client(
		{
			host = host, port = port,
		}
	)
	local db = c["admin"]
	assert(db:auth(username, password))

  db = c[db_name]

	db.testcoll:dropIndex("*")
	db.testcoll:drop()

	ok, err, ret = db.testcoll:safe_insert({test_key = 1});
	assert(ok and ret and ret.n == 1, err)

	ok, err, ret = db.testcoll:safe_insert({test_key = 1});
	assert(ok and ret and ret.n == 1, err)
end

local function test_insert_without_index()
	local ok, err, ret
	local c = _create_client()
	local db = c[db_name]

	db.testcoll:dropIndex("*")
	db.testcoll:drop()

	ok, err, ret = db.testcoll:safe_insert({test_key = 1});
	assert(ok and ret and ret.n == 1, err)

	ok, err, ret = db.testcoll:safe_insert({test_key = 1});
	assert(ok and ret and ret.n == 1, err)
end

local function test_insert_with_index()
	local ok, err, ret
	local c = _create_client()
	local db = c[db_name]

	db.testcoll:dropIndex("*")
	db.testcoll:drop()

	db.testcoll:ensureIndex({test_key = 1}, {unique = true, name = "test_key_index"})

	ok, err, ret = db.testcoll:safe_insert({test_key = 1})
	assert(ok and ret and ret.n == 1, err)

	ok, err, ret = db.testcoll:safe_insert({test_key = 1})
	assert(ok == false and string.find(err, "duplicate key error"))
end

local function test_find_and_remove()
	local ok, err, ret
	local c = _create_client()
	local db = c[db_name]

	db.testcoll:dropIndex("*")
	db.testcoll:drop()

	local cursor = db.testcoll:find()
	assert(cursor:hasNext() == false)

	db.testcoll:ensureIndex({test_key = 1}, {test_key2 = -1}, {unique = true, name = "test_index"})

	ok, err, ret = db.testcoll:safe_insert({test_key = 1, test_key2 = 1})
	assert(ok and ret and ret.n == 1, err)

	cursor = db.testcoll:find()
	assert(cursor:hasNext() == true)
	local v = cursor:next()
	assert(v)
	assert(v.test_key == 1)

	ok, err, ret = db.testcoll:safe_insert({test_key = 1, test_key2 = 2})
	assert(ok and ret and ret.n == 1, err)

	ok, err, ret = db.testcoll:safe_insert({test_key = 2, test_key2 = 3})
	assert(ok and ret and ret.n == 1, err)

	ret = db.testcoll:findOne({test_key2 = 1})
	assert(ret and ret.test_key2 == 1, err)

	ret = db.testcoll:find({test_key2 = {['$gt'] = 0}}):sort({test_key = 1}, {test_key2 = -1}):skip(1):limit(1)
	assert(ret:count() == 3)
	assert(ret:count(true) == 1)
	if ret:hasNext() then
		ret = ret:next()
	end
	assert(ret and ret.test_key2 == 1)

	db.testcoll:delete({test_key = 1})
	db.testcoll:delete({test_key = 2})

	ret = db.testcoll:findOne({test_key = 1})
	assert(ret == nil)
end

local function test_runcommand()
	local ok, err, ret
	local c = _create_client()
	local db = c[db_name]

	db.testcoll:dropIndex("*")
	db.testcoll:drop()

	ok, err, ret = db.testcoll:safe_insert({test_key = 1, test_key2 = 1})
	assert(ok and ret and ret.n == 1, err)

	ok, err, ret = db.testcoll:safe_insert({test_key = 1, test_key2 = 2})
	assert(ok and ret and ret.n == 1, err)

	ok, err, ret = db.testcoll:safe_insert({test_key = 2, test_key2 = 3})
	assert(ok and ret and ret.n == 1, err)

	local pipeline = {
		{
			["$group"] = {
				_id = mongo.null,
				test_key_total = { ["$sum"] = "$test_key"},
				test_key2_total = { ["$sum"] = "$test_key2" },
			}
		}
	}
	ret = db:runCommand("aggregate", "testcoll", "pipeline", pipeline, "cursor", {})
	assert(ret and ret.cursor.firstBatch[1].test_key_total == 4)
	assert(ret and ret.cursor.firstBatch[1].test_key2_total == 6)
end

local function test_expire_index()
	local ok, err, ret
	local c = _create_client()
	local db = c[db_name]

	db.testcoll:dropIndex("*")
	db.testcoll:drop()

	db.testcoll:ensureIndex({test_key = 1}, {unique = true, name = "test_key_index", expireAfterSeconds = 1, })
	db.testcoll:ensureIndex({test_date = 1}, {expireAfterSeconds = 1, })

	ok, err, ret = db.testcoll:safe_insert({test_key = 1, test_date = bson.date(os.time())})
	assert(ok and ret and ret.n == 1, err)

	ret = db.testcoll:findOne({test_key = 1})
	assert(ret and ret.test_key == 1)

	for i = 1, 60 do
		ngx.sleep(1);
		print("check expire", i)
		ret = db.testcoll:findOne({test_key = 1})
		if ret == nil then
			return
		end
	end
	print("test expire index failed")
	assert(false, "test expire index failed");
end

local function test_safe_batch_insert()
	local ok, err, ret
	local c = _create_client()
	local db = c[db_name]

	db.testcoll:drop()
	
	local docs, length = {}, 10
	for i = 1, length do
		table.insert(docs, {test_key = i})
	end
	
	db.testcoll:safe_batch_insert(docs)

	local ret = db.testcoll:find()
	assert(length == ret:count(), "test safe batch insert failed")
end

local function test_safe_batch_delete()
	local ok, err, ret
	local c = _create_client()
	local db = c[db_name]

	db.testcoll:drop()

	local docs, length = {}, 10
	for i = 1, length do
		table.insert(docs, {test_key = i})
	end

	db.testcoll:safe_batch_insert(docs)

	docs = {}
	local del_num = 5
	for i = 1, del_num do
		table.insert(docs, {test_key = i})
	end

	db.testcoll:safe_batch_delete(docs)

	local ret = db.testcoll:find()
	assert((length - del_num) == ret:count(), "test safe batch delete failed")
end

local function test_safe_update()
	local ok, err, ret
	local c = _create_client()
	local db = c[db_name]

	db.testcoll:drop()

	db.testcoll:safe_insert({test_key = 100, test_value = "hello mongo"})
	
	db.testcoll:ensureIndex({test_key = 1}, {unique = true, name = "test_key_index"})

	local query = {test_key = 100}
	local update = {test_value = "hi mongo"}
	ok, err = db.testcoll:safe_update(query, {['$set'] = update})
	assert(ok, err)

	ret = db.testcoll:findOne(query)
	assert(ret.test_value == "hi mongo")
end

local function test_unsafe_insert()
	local ok, err, ret
	local c = _create_client()
	local db = c[db_name]
	db.testcoll:drop()
	db.testcoll:insert({value = "foo"})
	db.testcoll:insert({value = "bar"})
	db.testcoll:insert({value = "foobar"})
  
  local cur = db.testcoll:find({ value = {["$exists"] = true}})
  while cur:hasNext() do
    local v = cur:next()
    assert(v)
    local typ, val = bson.type(v.value)
    print(typ, ": ", val)
  end
end

if username then
  print("Test auth")
  test_auth()
end
print("Test insert without index")
test_insert_without_index()
print("Test insert index")
test_insert_with_index()
print("Test find and remove")
test_find_and_remove()
print("Test runCommand")
test_runcommand()
print("Test expire index")
test_expire_index()
print("test safe batch insert")
test_safe_batch_insert()
print("test safe batch delete")
test_safe_batch_delete()
print("test_safe_update")
test_safe_update()
print("test_unsafe_insert")
test_unsafe_insert()
print("mongodb test finish.");
