local NEW_TABLE_QUERY = [[
CREATE TABLE %s (
    key TEXT PRIMARY KEY, 
    value TEXT,
    metadata TEXT 
);

CREATE UNIQUE INDEX idx_%s on %s (key)
]];

type HttpMethod = "GET" | "POST" | "PUT" | "DELETE" | "HEAD" | "OPTIONS" | "PATCH";

type HttpQueryOrHeaderMap = { [string]: string | { string } };
type HttpQueryMap = HttpQueryOrHeaderMap;
type HttpHeaderMap = HttpQueryOrHeaderMap;

type FetchParams = {
	url: string,
	method: HttpMethod?,
	body: (string | buffer)?,
	query: HttpQueryMap?,
	headers: HttpHeaderMap?,
};

type FetchResponse = {
	ok: boolean,
	statusCode: number,
	statusMessage: string,
	headers: HttpHeaderMap,
	body: string?,
};

local context;
       
if game and task then
    context = "roblox";
else
    local ok, net = pcall(function()
        return require("@lune/net");
    end);

    if ok and net then
        context = "lune"
    end
end

assert(context, "Unable to determine context. Please specify in options.");

local net = {};

if context == "roblox" then
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
elseif context == "lune" then
    local lune_net = require("@lune/net");
    net.request = lune_net.request :: any;
    net.jsonEncode = lune_net.jsonEncode :: any;
    net.jsonDecode = lune_net.jsonDecode :: any;
end

local function ser(val: any): any
    return net.jsonEncode(val);
end

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

local DataStoreKeyInfo = {};
do
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

local DataStore = {};
do
    DataStore.__index = DataStore;
    
    -- FIXME: SQL INJECTION POSSIBILITY. MAKE KNOWN IN DOCUMENTATION. --
    function DataStore.new(wrapper: any, name: string, create_if_non_existant: boolean?)
        if create_if_non_existant then
            local res = wrapper:query("SELECT * FROM sqlite_master where type == \"table\" and name = ?", {name});
            if res.ok and #net.jsonDecode(res.body).result[1].results == 0 then
                wrapper:query(NEW_TABLE_QUERY:format(name, name, name));
            end
        end
    
        local self = setmetatable({}, DataStore);
    
        self.name = name;
        self.wrapper = wrapper;
    
        return self;
    end
    
    function DataStore:get_async(key: string): (any, DataStoreKeyInfo)
        local res = self.wrapper:query(`SELECT * FROM {self.name} WHERE key = ?`, {key});
        assert(res.ok, res.statusMessage);
    
        local data = net.jsonDecode(res.body);
        
        local value = deser(data.result[1].results[1] and data.result[1].results[1].value);
        local key_info = DataStoreKeyInfo.new(1, 1, "", {});

        return value, key_info;
    end
    
    function DataStore:set_async(key: string, value: any)
        if self:get_async(key) then
            local res = self.wrapper:query(`UPDATE {self.name} SET value = ? WHERE key = ?`, {ser(value), key});
            assert(res.ok, res.statusMessage);
        else
            local res = self.wrapper:query(`INSERT INTO {self.name} (key, value) VALUES (?, ?)`, {key, ser(value)});
            assert(res.ok, res.statusMessage);
        end
    end
    
    function DataStore:update_async(key: string, update_func: (any)->(any))
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
    
    function DataStore:remove_async(key: string)
        local res = self.wrapper:query(`DELETE FROM {self.name} WHERE key = ?`, {key});
        assert(res.ok, res.statusMessage);
    end

    function DataStore:increment_async(key: string, delta: number)
        return self:update_async(key, function(old)
            old += delta;
            return old;
        end);
    end
    
    DataStore.GetAsync = DataStore.get_async;
    DataStore.SetAsync = DataStore.set_async;
    DataStore.UpdateAsync = DataStore.update_async;
    DataStore.RemoveAsync = DataStore.remove_async;
    DataStore.IncrementAsync = DataStore.increment_async;
end

local auth_map = {};

type D1WrapperOptions = {
    account_id: string,
    database_id: string,
    auth: string | Secret 
};

local D1Wrapper = {};
D1Wrapper.__index = D1Wrapper;

function D1Wrapper.new(options: D1WrapperOptions)
    local self = setmetatable({}, D1Wrapper);

    self.url = `https://api.cloudflare.com/client/v4/accounts/{options.account_id}/d1/database/{options.database_id}/query`;
    auth_map[self] = options.auth;

    return self;
end

function D1Wrapper:get_data_store(name: string)
    return DataStore.new(self, name, true);
end

D1Wrapper.GetDataStore = D1Wrapper.get_data_store;

function D1Wrapper:query(sql: string, params: {string}?)
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

    return res;
end

return D1Wrapper;
