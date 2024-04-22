<!-- markdownlint-disable MD041 -->
<!-- markdownlint-disable MD033 -->
<!-- markdownlint-disable MD001 -->
<!-- markdownlint-disable MD022 -->
<!-- markdownlint-disable MD024 -->

<div align="center">

# API Reference

</div>

# Types

### `D1WrapperOptions`
> The D1WrapperOptions type is used in the creation of D1 class.
>
> ```lua
> type D1WrapperOptions = {
>     account_id: string,
>     database_id: string,
>     auth: string | Secret 
> };
> ```

### `QueryResult`
> The QueryResult type represents a response from the CF D1 Query API.
>
> ```lua
> {
>     errors: {},
>     messages: {},
>     success: boolean,
>     result: {
>         {
>             meta: {
>                 changed_db: boolean,
>                 changes: number,
>                 duration: number,
>                 last_row_id: number,
>                 rows_read: number,
>                 rows_written: number,
>                 size_after: number,
>             },
>             results: { {[string]: any} },
>             success: boolean,
>         }
>     }
> };
> ```

## `D1` Class

The D1 class is the class that wraps around a D1 Database. It attempts to conform to the DataStoreService API.

The database credentials are stored as a local within the library, instead of a propery in the D1 class. This means passing the D1 class should not expose information about the underlying database.

### Methods

#### `D1.new(options: D1WrapperOptions): D1`
> Constructs a new D1 Database wrapper with the specified options.
>
> This will throw an error if Luau-D1 is unable to query the database with the passed credentials.
>
> ```lua
> local D1DataStoreService = D1.new({
>     auth = "Bearer <key>",
>     account_id = "3473547545488",
>     database_id = "sdgsdfgdfdf"
> });
> ```

#### `D1:query(sql: string, params: {string}): QueryResult`
> Sends an SQL query to the connected database.
>
> ```lua
> local res = D1DataStoreService:query("SELECT * FROM test WHERE id=?", {"6467823"});
> ```

#### `D1:get_data_store(name: string): D1DataStore`
> Gets a datastore.
>
> In an effort to mitigate potential SQL injection, anything that doesn't conform to the character class `[^%w_-]` will be stripped from the name argument. This means only alphanumeric characters, underscores and dashes are permitted. You should still be cautious when accepting user input for the name argument.
>
> If the specified table does not exist within the database, it will be created.
>
> `D1:GetDataStore` is an alias for this method.
>
> ```lua
> local res = D1DataStoreService:get_data_store("hello");
> ```

## `D1DataStore` Class

The D1DataStore class is the class that wraps around a D1 Database SQL table.

It expects the table to be in the following schema:

```sql
CREATE TABLE <name> (
    key TEXT PRIMARY KEY, 
    value TEXT,
    metadata TEXT 
);
```

If the table didn't already exist prior to calling `D1:get_data_store`, it will be created to this specification automatically.

### Methods

#### `D1DataStore:get_async(key: string): (any)`
> Gets the value of a record.
> Returns nil if the record doesn't exist.
> May throw an error.
>
> `D1DataStore:GetAsync` is an alias for this method.
>
> ```lua
> print(D1DataBase:get_async("test_key")); --> "hi"
> ```

#### `D1DataStore:set_async(key: string, value: any)`
> Sets the value of a record.
> Value is serialised into JSON internally.
> May throw an error.
>
> `D1DataStore:SetAsync` is an alias for this method.
>
> ```lua
> D1DataBase:set_async("test_key", 100);
> ```

#### `D1DataStore:update_async(key: string, update_func: (old: any)->(any))`
> Transforms a record with the specified transform function.
> Value is serialised into JSON internally.
> May throw an error.
>
> `D1DataStore:UpdateAsync` is an alias for this method.
>
> ```lua
> D1DataBase:update_async("logs", function(old: {string}): {string}
>    table.insert(old, "Hello, World!");
>    return old;
> end);
> ```

#### `D1DataStore:remove_async(key: string)`
> Removes a record.
> May throw an error.
>
> `D1DataStore:RemoveAsync` is an alias for this method.
>
> ```lua
> D1DataBase:remove_async("test_key");
> ```

#### `D1DataStore:increment_async(key: string, delta: number)`
> Updates a record by adding `delta` to the value.
> The value must be a Lua number prior to calling this method.
> May throw an error.
>
> `D1DataStore:IncrementAsync` is an alias for this method.
>
> ```lua
> D1DataBase:increment_async("test_key", 10);
> ```
