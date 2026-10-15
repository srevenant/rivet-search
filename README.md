# Rivet.Search

A schema-driven search engine which builds dynamic Ecto queries from user-provided
filters, with support for input validation, multi-column ordering, and optional joins.

There are three parts to implementation:

- [Creating the Module](#creating-the-module)
- [Defining the Schema](#defining-the-schema)
- [Frontend Integration](#frontend-integration)

**See also:**

- `Rivet.Search.MixedAuth` — Authentication and authorization-aware search routing.
- `Rivet.Search.Result` — Standardized search results and status responses.
- `Rivet.Search.Tools` — Helpers for custom filtering and query construction.
- `Rivet.Search.Pagination` — Pagination strategies (work in progress).

## Creating the Module

Your [Schema](#defining-the-schema) is defined in your Search module, as shown below. You can implement optional callbacks here, such as `c:Rivet.Search.filter_expr/3`, to customize how filter inputs are converted into Ecto expressions.

```elixir
defmodule MyApp.RivetModel.Search do
  schema = [
    status: [type: :atom, list: :in],
    name: [type: :glob],
    inserted_at: [type: :date, order: :only],
    updated_at: [type: :date, order: :only]
  ]

  default_filter = [[n: "name"]]

  use Rivet.Search, schema: schema, default_filters: default_filters

  @impl Rivet.Search
  def filter_expr(:name, ..)

```

This will generate a search function that supports a map with either `:filter` or `:id` as a key (filter taking priority).

Options you can give to the creation of a search model:

* `:schema` - REQUIRED the overall Schema for this search module (see below).
* `:default_filters` - default filter set when no user-supplied filters are provided (infills missing columns too).
* `:soft_limit` - default=25 - this is the default result limit if there is not a user-supplied limit.
* `:hard_limit` - default=400 - this is the max a user-supplied limit can have.


## Defining the Schema

Each search module defines a schema describing which filters are available and how they are processed. The schema is used during filter preparation to validate incoming values, resolve database columns, configure joins, and determine ordering behavior before building the Ecto query.

The schema is a collection of schemes, one for each searchable column. Each scheme is identified by a key corresponding to the incoming filter's name (`n:`), with a keyword list specifying its behavior.

Each scheme supports the following options:

- `type: type` — **Required.** Specifies the built-in input type used to validate and prepare the incoming value. See [Input Validation](#input-validation). Additional processing can be provided through the `:prep` callback.
- `prep: callback` — Specifies a custom input-preparation callback, supporting arities 1, 2, and 3. See [Preparation Callback](#preparation-callback).
- `list: false | :in` — Defaults to `false`. When set to `:in`, the filter expects a list of values and generates an SQL `IN` comparison.
- `key: :atom` — Overrides the database column name used by the filter. Normally, the column name matches the scheme's name.
- `join: callback` — Specifies a custom join callback when the default join configuration is insufficient. Accepts `&func/3` or `{:join_key, &func/3}`. See [Join Callback](#join-callback).
- `order: true | false | :only | callback` — Controls ordering behavior. Defaults to `true`. Set to `false` to disable ordering, or `:only` to make the filter available exclusively for ordering without contributing a WHERE condition. A custom `&func/4` can provide specialized ordering behavior. See [Order Callback](#order-callback).

**Development Note:** While Schemes are submitted as a keyword list, internally they are represented as maps.

### Input Validation

Input validation and preparation occur in two stages. First, the built-in `type` validates or converts the incoming value. An optional `prep` callback can then perform additional validation or transformation.

Every scheme must specify a built-in type, even when using a custom preparation callback.

The built-in types provide straightforward conversions:

- `:string` — Accept the value as a string without modification.
- `:glob` — Trim the input, escape backslash (`\`), percent (`%`), and underscore (`_`) characters, and wrap the result in `%` wildcards for substring matching. Input is limited to 128 characters. When used as a bound Ecto query parameter (default Ecto behavior), the pattern is protected against SQL injection; escaping ensures that user-supplied wildcard characters are treated literally.
- `:uuid` — Validate against a UUID version 4 pattern.
- `:atom` — Convert the input to an *existing* atom.
- `:integer` — Convert the input to an integer.
- `:float` — Convert the input to a float.
- `:date` — Convert the input to a datetime.

### Join Callback

A custom join callback (`&func/3`) is used to construct or reuse Ecto joins when the built-in join behavior is insufficient.

It receives:

`(join_key, query, state)`

- `join_key` — The join identifier being requested.
- `query` — The current Ecto query.
- `state` — The current filter state `%Rivet.Search{}`.

It must return one of:

- `{:ok, query, state}` — The updated Ecto query and filter state.
- `{:error, reason}` — An error that stops query construction.

The optional `{:join_key, &func/3}` form allows multiple filters to share the same logical join. For example, filters named `:vlan` and `:vlan_id` may both reference the `:vlan` join, avoiding unnecessary duplicate joins.

The callback should preserve existing query bindings and update the filter state as needed to reflect the joins it creates.

### Preparation Callback

A preparation callback provides additional validation or transformation of filter values after the built-in type has been processed.

Three callback arities are supported:

- `&func/1` — Receives `(value)`.
- `&func/2` — Receives `(value, spec)`.
- `&func/3` — Receives `(value, spec, state)`.

Where:

- `value` — The filter value after built-in type preparation.
- `spec` — The scheme specification for the current filter.
- `state` — The current filter state (`%Rivet.Search{}`).

All three arities follow the same return convention:

- `{:ok, value}` — Accept the prepared value and continue processing.
- `:skip` — Exclude this filter entirely, including its filtering, ordering, and join requirements.
- `{:error, reason}` — Reject the filter and stop preparation.

Preparation callbacks are useful for validation beyond the base type, such as restricting an `:atom` input to an allowed set of enum values.

### Order Callback

A custom order callback (`&func/4`) provides specialized ordering instructions when standard column ordering is insufficient.

It receives:

`(state, direction, filter, spec)`

- `state` — The current filter state (`%Rivet.Search{}`).
- `direction` — The resolved ordering direction, `:asc` or `:desc`.
- `filter` — The prepared search filter, including its column name, value, and ordering information.
- `spec` — The scheme specification for that filter.

It must return one of:

- `{:ok, order}` — An Ecto-compatible keyword list describing the requested ordering.
- `{:error, reason}` — An error that stops query construction.

The `order` value must be a valid keyword list suitable for Ecto's `order_by` expression.

Custom ordering is useful for computed fields, expressions involving joined tables, and ordering rules that cannot be represented by a simple column reference.

## Frontend Integration

### Search Filters

The frontend sends an ordered list of column filters, combining filtering and sorting instructions in a single request. Each filter identifies a column, its optional comparison values and operator, and its sort direction. If multiples of the same column name are specified, only the last is valid.

The position of each filter in the list determines its sorting precedence. For example, the first filter has the highest priority in the resulting `ORDER BY` clause.

To keep request payloads compact, filter objects use short keys:

* `:n` — **Name** (required). Identifies a column defined in the search schema.
* `:o` — **Order**. `:a` for ascending or `:d` for descending. Defaults to ascending unless overridden by the schema.
* `:v` — **Value**. An optional list of strings to filter against. Even a single value must be supplied as a list to maintain a consistent GraphQL input type. Omitting the value allows a column to participate in sorting without filtering.
* `:x` — **Operator**. Determines how the value is compared:
  * `:is` — Equal to, pattern matching, or within a list. Default.
  * `:no` — Not equal to, not matching, or not within a list.
  * `:lt`* — Less than.
  * `:le`* — Less than or equal to.
  * `:gt`* — Greater than.
  * `:ge`* — Greater than or equal to.

\* The comparison operators `:lt`, `:le`, `:gt`, and `:ge` apply to numeric and date values. List comparisons require the corresponding scheme to support `list: :in`.

***Example***

The following JavaScript-style request searches by location and serial number,
excludes two condition values, and includes additional columns for ordering:

```javascript
[
  {n: "location", o: "a", v: ["a-location-name"]},
  {n: "serial", v: ["Q53"]},
  {n: "loc"},
  {n: "cond", v: ["failing", "servicing"], x: "no"},
  {n: "sku"}
]
```

Keys are shown without quotes using JavaScript object syntax. When transmitted
as JSON, keys must be quoted.

### GraphQL schema

Schema for GraphQL should include:

```elixir
enum :filter_order do
  value(:a)
  value(:d)
end

enum :filter_operator do
  value(:is)
  value(:no)
  value(:lt)
  value(:le)
  value(:gt)
  value(:ge)
end

input_object :filter_column do
  field(:n, non_null(:string))
  field(:v, list_of(:string))
  field(:o, :filter_order)
  field(:x, :filter_operator, default_value: :is)
end
```

then it can be used simply as:

```elixir
  arg(:filter, list_of(:filter_column), default_value: [])
```
