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
local function ser(val: any): any
    return net.jsonEncode(val);
end

--[[
    Deserialises data back into Lua types.
]]
local function deser(val: any): any
    if not val then
        return val;
    else
        return net.jsonDecode(val);
    end
end

local function create_metadata(create_t: number, update_t: number, userids: {number}, metadata: {[string]: any})
    return net.jsonEncode({
        created = create_t,
        updated_time = update_t,
        user_ids = userids,
        metadata = metadata,
    });
end


--[[
    Class used to store information about a key.
]]
local DataStoreKeyInfo = {}; do
    DataStoreKeyInfo.__index = DataStoreKeyInfo;

    function DataStoreKeyInfo.new(created_time: number, updated_time: number, version: string, metadata: {[any]: any})
        local self = setmetatable({}, DataStoreKeyInfo);

        self.CreatedTime = metadata.created_time;
        self.UpdatedTime = metadata.updated_time;
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

--[[
    Class used to wrap a D1 Database table.
]]
local D1DataStore = {}; do
    D1DataStore.__index = D1DataStore;
    
    -- SQL INJECTION POSSIBILITY. MAKE KNOWN IN DOCUMENTATION. --
    function D1DataStore.new(wrapper: any, name: string, create_if_non_existant: boolean?)
        local safe_name = name:gsub("[^%w_-]", "");
        
        if create_if_non_existant then
            local res = wrapper:query("SELECT * FROM sqlite_master where type == \"table\" and name = ?", {name});
            if res.ok and #net.jsonDecode(res.body).result[1].results == 0 then
                wrapper:query(NEW_TABLE_QUERY:format(safe_name, safe_name, safe_name));
            end
        end
    
        local self = setmetatable({}, D1DataStore);
    
        self.name = name;
        self.wrapper = wrapper;
    
        return self;
    end
    
    function D1DataStore:get_async(key: string): (any, DataStoreKeyInfo)
        local res = self.wrapper:query(`SELECT * FROM {self.name} WHERE key = ?`, {key});
        assert(res.ok, res.statusMessage);
    
        local data = net.jsonDecode(res.body);
        
        local value = deser(data.result[1].results[1] and data.result[1].results[1].value);
        local key_info = DataStoreKeyInfo.new(1, 1, "", {});

        return value, key_info :: any;
    end
    
    function D1DataStore:set_async(key: string, value: any)
        if self:get_async(key) then
            local res = self.wrapper:query(`UPDATE {self.name} SET value = ? WHERE key = ?`, {ser(value), key});
            assert(res.ok, res.statusMessage);
        else
            local res = self.wrapper:query(`INSERT INTO {self.name} (key, value) VALUES (?, ?)`, {key, ser(value)});
            assert(res.ok, res.statusMessage);
        end
    end
    
    function D1DataStore:update_async(key: string, update_func: (old: any)->(any))
        local old_value = self:get_async(key);
        local value = update_func(old_value);
        
        if old_value then
            local res = self.wrapper:query(`UPDATE {self.name} SET value = ? WHERE key = ?`, {ser(value), key});
            assert(res.ok, res.statusMessage);
        else
            local res = self.wrapper:query(`INSERT INTO {self.name} (key, value) VALUES (?, ?)`, {key, ser(value)});
            assert(res.ok, res.statusMessage);
        end
    end
    
    function D1DataStore:remove_async(key: string)
        local res = self.wrapper:query(`DELETE FROM {self.name} WHERE key = ?`, {key});
        assert(res.ok, res.statusMessage);
    end

    function D1DataStore:increment_async(key: string, delta: number)
        return self:update_async(key, function(old: number)
            assert(typeof(old) == "number", "Value must be of type number.");

            old += delta;
            return old;
        end);
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

        return self;
    end

    function D1:get_data_store(name: string)
        return D1DataStore.new(self, name:gsub("[^%w_-]", ""), true);
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
end

return D1;
