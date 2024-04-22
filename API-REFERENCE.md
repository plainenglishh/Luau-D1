<!-- markdownlint-disable MD041 -->
<!-- markdownlint-disable MD033 -->
<!-- markdownlint-disable MD001 -->
<!-- markdownlint-disable MD022 -->

<div align="center">

# API Reference

</div>

# Types

## `D1WrapperOptions`
> D1WrapperOptions is used in the creation of D1 class.
>
> ```lua
> type D1WrapperOptions = {
>     account_id: string,
>     database_id: string,
>     auth: string | Secret 
> };
> ```

## `D1` Class

The D1 class is the class that wraps around a D1 Database. It attempts to conform to the DataStoreService API.

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
