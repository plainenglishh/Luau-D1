--!strict

--[[
    Luau-D1 - plainenglish

    Copyright © 2024 plainenglish

    Permission is hereby granted, free of charge, to any person obtaining a
    copy of this software and associated documentation files (the “Software”),
    to deal in the Software without restriction, including without limitation
    the rights to use, copy, modify, merge, publish, distribute, sublicense,
    and/or sell copies of the Software, and to permit persons to whom the
    Software is furnished to do so, subject to the following conditions:

    The above copyright notice and this permission notice shall be included in
    all copies or substantial portions of the Software.

    THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
    IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
    FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
    AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
    LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
    FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
    DEALINGS IN THE SOFTWARE.
]]

local NEW_TABLE_QUERY = [[CREATE TABLE %s (
    key TEXT PRIMARY KEY, 
    value TEXT,
    metadata TEXT 
);

CREATE UNIQUE INDEX idx_%s on %s (key)]];
export type QueryResult = {
    errors: {},
    messages: {},
    success: boolean,
    result: {
        {
            meta: {
                changed_db: boolean,
                changes: number,
                duration: number,
                last_row_id: number,
                rows_read: number,
                rows_written: number,
                size_after: number,
            },
            results: { {[string]: any} },
            success: boolean,
        }
    }
};

export type D1WrapperOptions = {
    account_id: string,
    database_id: string,
    auth: string | Secret 
};

type KeyIdentifier = number;
type Dictionary = {[any]: any};

type FetchParams = {
	url: string,
	method: "GET" | "POST" | "PUT" | "DELETE" | "HEAD" | "OPTIONS" | "PATCH"?,
	body: (string | buffer)?,
	query: { [string]: string | { string } }?,
	headers: { [string]: string | { string } }?,
};

type FetchResponse = {
	ok: boolean,
	statusCode: number,
	statusMessage: string,
	headers: { [string]: string | { string } },
	body: string?,
};

local function determine_runtime(): "roblox"|"lune"
    local runtime;
       
    if game and task then
        runtime = "roblox";
    else
        local ok, net = pcall(function()
            return require("@lune/net");
        end);

        if ok and net then
            runtime = "lune"
        end
    end

    assert(runtime, "Unable to determine context. Please specify in options.");

    return runtime :: any;
end

local function sanetise(name: string)
    return name:gsub("[^%w_-]", "");
end

--[[
    Creates a limited, runtime dependent version of the lune net builtin.
    Allows for portibility across lune & roblox codebases within a single module.
]]
local function create_net()
    local runtime = determine_runtime();

    local net = {};

    if runtime == "roblox" then
        local http_service = game:GetService("HttpService");
        function net.request(config: string | FetchParams): FetchResponse
            local options: FetchParams;
            if typeof(config) == "string" then
                options = { url = config };
            else
                options = config;
            end

            local res = http_service:RequestAsync({
                Url = options.url,
                Method = options.method or "GET",
                Headers = options.headers :: any,
                Body = options.body
            });

            return {
                statusCode = res.StatusCode,
                statusMessage = res.StatusMessage,
                body = res.Body,
                headers = res.Headers,
                ok = res.Success
            };
        end

        function net.jsonEncode(value: any): string
            return http_service:JSONEncode(value);
        end

        function net.jsonDecode(encoded: string): any
            return http_service:JSONDecode(encoded);
        end
    elseif runtime == "lune" then
        local lune_net = require("@lune/net");
        net.request = lune_net.request :: any;
        net.jsonEncode = lune_net.jsonEncode :: any;
        net.jsonDecode = lune_net.jsonDecode :: any;
    end

    return net;
end

local net = create_net();

--[[
    Serialises data for storage.
]]
local function serialise(val: any): any
    return net.jsonEncode(val);
end

--[[
    Deserialises data back into Lua types.
]]
local function deserialise(val: any): any
    if not val then
        return val;
    else
        return net.jsonDecode(val);
    end
end

local DataStoreSetOptions = {}; do
    DataStoreSetOptions.__index = DataStoreSetOptions;

    function DataStoreSetOptions.new(metadata: Dictionary)
        local self = setmetatable({}, DataStoreSetOptions);

        self._metadata = metadata;

        return self;
    end

    function DataStoreSetOptions:get_metadata(): Dictionary
        return self._metadata;
    end

    function DataStoreSetOptions:set_metadata(attributes: Dictionary)
        self._metadata = attributes;
    end

    -- Roblox Compatibility --
    DataStoreSetOptions.GetMetadata = DataStoreSetOptions.get_metadata;
    DataStoreSetOptions.SetMetadata = DataStoreSetOptions.set_metadata;
end

local DataStoreGetOptions = {}; do
    DataStoreGetOptions.__index = DataStoreGetOptions;

    function DataStoreGetOptions.new()
        local self = setmetatable({}, DataStoreGetOptions);

        self.UseCache = false;

        return self;
    end
end

--[[
    Class used to store information about a key.
]]
local DataStoreKeyInfo = {}; do
    DataStoreKeyInfo.__index = DataStoreKeyInfo;

    function DataStoreKeyInfo.new(metadata: Dictionary)
        local self = setmetatable({}, DataStoreKeyInfo);

        self.CreatedTime = metadata.created;
        self.UpdatedTime = metadata.updated;
        self.Version = metadata.version;

        self._metadata = metadata;

        return self;
    end

    function DataStoreKeyInfo:GetMetadata()
        return self._metadata.metadata;
    end

    function DataStoreKeyInfo:GetUserIds()
        return self._metadata.user_ids;
    end
end

local function create_version_identifier(): KeyIdentifier
    return math.random(0, 999999);
end

--[[
    Class used to wrap a D1 Database table.
]]
local D1DataStore = {}; do
    D1DataStore.__index = D1DataStore;

    local function write_key(datastore, key: string, value: any, metadata: Dictionary?, overwrite: boolean): KeyIdentifier
        local _metadata = (metadata or {}) :: Dictionary;
        local t = os.time();

        _metadata.created = _metadata.created or t;
        _metadata.updated = t;
        _metadata.user_ids = _metadata.user_ids or {};
        _metadata.metadata = _metadata.metadata or {};
        _metadata.version = create_version_identifier();

        local res;
        if overwrite then
            res = datastore.wrapper:query(`UPDATE {sanetise(datastore.name)} SET value=?, metadata=? WHERE key=?`, {serialise(value), serialise(_metadata), key});
        else
            res = datastore.wrapper:query(`INSERT INTO {sanetise(datastore.name)} (key, value, metadata) VALUES (?, ?, ?)`, {key, serialise(value), serialise(_metadata)});
        end

        assert(res.ok, res.statusMessage);
        
        return _metadata.version;
    end
    
    local function read_key(datastore, key): (any, DataStoreKeyInfo?)
        local res = datastore.wrapper:query(`SELECT * FROM {sanetise(datastore.name)} WHERE key = ?`, {key});
        assert(res.ok, res.statusMessage);

        local data = net.jsonDecode(res.body).result[1].results[1];
        if data then
            data.value = deserialise(data.value);
            data.metadata = deserialise(data.metadata);

            return data, DataStoreKeyInfo.new(data.metadata) :: any;
        else
            return nil, nil;
        end
    end

    local function remove_key(datastore, key)
        local res = datastore.wrapper:query(`DELETE FROM {sanetise(datastore.name)} WHERE key = ?`, {key});
        assert(res.ok, res.statusMessage);
    end

    -- SQL INJECTION POSSIBILITY. MAKE KNOWN IN DOCUMENTATION. --
    function D1DataStore.new(wrapper: any, name: string, create_if_non_existant: boolean?)
        local safe_name = sanetise(name);
        
        if create_if_non_existant then
            if not wrapper:table_exists(name) then
                wrapper:query(NEW_TABLE_QUERY:format(safe_name, safe_name, safe_name));
            end
        end
    
        local self = setmetatable({}, D1DataStore);
    
        self.name = safe_name;
        self.wrapper = wrapper;
        self.cache = {};
        table.freeze(self);

        return self;
    end
    
    function D1DataStore:get_async(key: string, options: DataStoreGetOptions?): (any, DataStoreKeyInfo?)
        local caching = options and options.UseCache;

        if caching and self.cache[key] then
            return unpack(self.cache[key]);
        end

        local data, key_info = read_key(self, key);
        
        if data then
            local value = data.value;
            if caching then
                self.cache[key] = {value, key_info};
            end
            return value, key_info;
        else
            return nil, nil;
        end
    end
    
    function D1DataStore:set_async(key: string, value: any, user_ids: {number}?, options: DataStoreSetOptions?): KeyIdentifier
        local old = read_key(self, key);

        if old then
            old.metadata.user_ids = user_ids;
            old.metadata.metadata = options and options:GetMetadata() or {};
        end

        return write_key(self, key, value, old and old.metadata or {
            metadata = options and options:GetMetadata() or nil,
            user_ids = user_ids,
        }, old ~= nil);
    end
    
    function D1DataStore:update_async(key: string, transform_function: (current: any, key_info: DataStoreKeyInfo)->(any, {number}?, Dictionary)): (any, DataStoreKeyInfo?)
        local old, key_info = read_key(self, key);
        local value, user_ids, metadata = transform_function(old, key_info :: any);

        if not value then
            return nil, nil;
        end

        if old then
            old.metadata.user_ids = user_ids;
            old.metadata.metadata = metadata;
        end

        write_key(self, key, value, old.metadata or {}, old ~= nil);
        return read_key(self, key);
    end
    
    function D1DataStore:remove_async(key: string): (any, DataStoreKeyInfo)
        local old, key_info = read_key(self, key);
        remove_key(self, key);
        return old, key_info :: any;
    end

    function D1DataStore:increment_async(key: string, delta: number, user_ids: {number}?, options: DataStoreSetOptions?): any
        local value, _ = self:update_async(key, function(old: number)
            assert(typeof(old) == "number", "Value must be of type number.");

            old += delta;
            return old, user_ids, options and options:GetMetadata() or nil;
        end);

        return value;
    end
    
    -- Roblox Compatibility --
    D1DataStore.GetAsync = D1DataStore.get_async;
    D1DataStore.SetAsync = D1DataStore.set_async;
    D1DataStore.UpdateAsync = D1DataStore.update_async;
    D1DataStore.RemoveAsync = D1DataStore.remove_async;
    D1DataStore.IncrementAsync = D1DataStore.increment_async;
end

--[[
    Wrapper for a D1 Database.
]]
local D1 = {}; do
    local auth_map = {};
    
    D1.__index = D1;

    function D1.new(options: D1WrapperOptions)
        local self = setmetatable({}, D1);

        self.url = `https://api.cloudflare.com/client/v4/accounts/{options.account_id}/d1/database/{options.database_id}/query`;
        auth_map[self] = options.auth;
        
        table.freeze(self);

        return self;
    end

    function D1:get_data_store(name: string)
        return D1DataStore.new(self, sanetise(name), true);
    end

    -- Roblox Compatibility --
    D1.GetDataStore = D1.get_data_store;

    function D1:query(sql: string, params: {string}?): QueryResult
        local res = net.request({
            url = self.url,
            headers = {
                authorization = auth_map[self] :: string,
            },
            method = "POST",
            body = net.jsonEncode({
                sql = sql,
                params = params,
            }),
        });

        return res :: any;
    end

    function D1:table_exists(name: string): boolean
        local res = self:query("SELECT * FROM sqlite_master where type == \"table\" and name = ?", {name});
        assert(res.ok, "Unable to query database.");
        return #net.jsonDecode(res.body).result[1].results ~= 0;
    end
end

local exports = {
    D1 = D1,
    DataStoreSetOptions = DataStoreGetOptions,
    DataStoreIncrementOptions = DataStoreGetOptions,
};

return exports;
