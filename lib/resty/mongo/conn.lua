local _M = {}

local unpack = table.unpack or unpack

local function try_connect(self)
  if self.closed then
    return nil, "closed"
  end
  if self.sock then
    return self.sock
  end
  local host_list = {}
  local host_set = {[string.format("%s:%d", self.host, self.port)] = true}
  local function update_hosts()
    if not self.backup then
      return
    end
    for i, v in ipairs(self.backup) do
      local host = v.host
      local port = tonumber(v.port) or 27017
      local key = string.format("%s:%d", host, port)
      if not host_set[key] then
        table.insert(host_list, {host, port})
        host_set[key] = true
      end
    end
  end
  local function connect_impl(host, port)
    local sock = ngx.socket.tcp()
    local ok, err = sock:connect(host or self.host, tonumber(port) or self.port, self.socket_opts)
    if not ok then
      local t = table.remove(host_list, 1)
      if not t then
        return nil, err
      end
      return connect_impl(unpack(t))
    end
    self.sock = sock
    if host then
      self.host = host
    end
    if tonumber(port) then
      self.port = tonumber(port)
    end
    if self.auth_cb then
      local ok, err = pcall(self.auth_cb)
      if ok then
        if not self.sock then
          return connect_impl()
        end
      else
        local sock = self.sock
        self.sock = nil
        sock:close()
        update_hosts()
        local t = table.remove(host_list, 1)
        if not t then
          return nil, "no more backup host"
        end
        return connect_impl(unpack(t))
      end
    end
    return self.sock
  end
  update_hosts()
  return connect_impl()
end

local _MT = {__index = {}}

function _MT.__index.connect(self)
  self.closed = false
  local sock, err = try_connect(self)
  if not sock then
    return nil, err
  end
  return true
end

function _MT.__index.close(self)
  if not self.__closed then
    self.__closed = true
    local sock = self.sock
    self.sock = nil
    sock:setkeepalive()
  end
end

function _MT.__index.request(self, request, rid)
  local sock, err = try_connect(self)
  if not sock then
    return nil, err
  end
  local n, err = sock:send(request)
  if not n then
    self.sock = nil
    return nil, err
  end
  if not rid or not self.resp_cb then
    return true
  end
  local id, ok, resp = self.resp_cb(sock)
  if not ok then
    if resp ~= "timeout" then
      self.sock = nil
    end
    return nil, resp
  end
  assert(id == rid, "request id mismatch")
  return resp
end

function _MT.__index.changebackup(self, backup)
  self.backup = backup
end

function _MT.__index.changehost(self, host, port)
  self.host = host
  self.port = tonumber(port) or 27017
  if not self.closed then
    local sock = self.sock
    self.sock = nil
    sock:setkeepalive()
  end
end

function _M.new(options)
  if type(options) ~= "table" then
    error("options of mongo connection MUST be a table.")
  end
  if type(options.host) ~= "string" then
    error("host of mongo connection MUST be a string.")
  end
  return setmetatable({
    host = options.host,
    port = tonumber(options.port) or 27017,
    backup = options.backup,
    auth_cb = options.auth,
    resp_cb = options.response,
    socket_opts = options.socket_opts,
    closed = true
  }, _MT)
end

return _M
