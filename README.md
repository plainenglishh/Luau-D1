# Luau-D1

# Installation

## Via LPM

```bash
lpm install plainenglishh/luau-d1
```

## From Source

Copy and paste `./lib/init.luau` into your project.

# Usage

Luau-D1 automatically determines the context (by the presense of the game & task globals in the case of Roblox, or the presence of the `@lune/net` builtin in the case of lune.)

```lua
local D1 = require("@lpm/luau-d1") or require(script.luau_d1);

local D1DataStoreService = D1.new({
    auth = "Bearer <key>",
    account_id = "3473547545488",
    database_id = "sdgsdfgdfdf"
});

local test_datastore = D1DataStoreService:GetDataStore("test_datastore"); -- get_data_store is also supported, for those who like snake_case.
print(test_datastore:GetAsync("test_key")); --> nil

test_datastore:SetAsync("test_key", 5);
print(test_datastore:GetAsync("test_key")); --> 5

test_datastore:IncrementAsync("test_key", 10);
print(test_datastore:GetAsync("test_key")); --> 15

test_datastore:UpdateAsync("test_key", function(old)
    return "Hello, World!";
end);
print(test_datastore:GetAsync("test_key")); --> "Hello, World!"

test_datastore:RemoveAsync("test_key");
print(test_datastore:GetAsync("test_key")); --> nil
```

# Notes

1. Using GetDataStore/get_data_store will automatically create the table if it doesn't exist.
