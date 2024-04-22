<!-- markdownlint-disable MD041 -->
<!-- markdownlint-disable MD033 -->
<!-- markdownlint-disable MD001 -->

<div align="center">

# Luau-D1

</div>

See also: [API Reference](./API-REFERENCE.md)

## About

Luau-D1 is a Luau library to serve as a Roblox DataStore-style wrapper around a Cloudflare D1 SQL Database.

## Installation

### LPM (Recommended)

If you're using a Lune project, you can install using the [Lua Package Manager](https://github.com/Spearhead-Industries/lpm).

```bash
lpm install plainenglishh/luau-d1
```

### From Source

Copy and paste `./lib/init.luau` into your project.

## Usage

### Runtimes

Luau-D1 will attempt to determine the runtime it is running within.

#### Supported Runtimes

|Runtime|Check Method|
|---|---|
|Roblox|Checks whether `game` and `task` globals are present.|
|Lune|Checks whether the `@lune/net` builtin is present.|

### Example Code

```lua
local D1 = require("@lpm/luau-d1"); -- or require(script.luau_d1), if using in roblox.

local D1DataStoreService = D1.new({
    auth = "Bearer <key>",
    account_id = "3473547545488",
    database_id = "sdgsdfgdfdf"
});

local test_datastore = D1DataStoreService:GetDataStore("test_datastore");
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

## Notes

1. Using GetDataStore will automatically create the table if it doesn't exist.
2. snake_case versions of all class methods are also available. (i.e DataStore:GetAsync = DataStore:get_async)

## Contributions

All contributions are accepted, simply submit a pull request. Please aim to keep the module within a single file.
