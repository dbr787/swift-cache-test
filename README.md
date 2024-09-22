# Swift Cache Test

A repository to test caching of Swift dependencies

## TODO

- add branch and commit to cache metadata and size? # of files?
- Update script to use a .build directory inside the cache volume
- Put cached vs not cached into step groups
- List created date as well as dirs and sizes
- Figure out how to build after the dependencies and how that works
  - I.e. the updated cache might not be available to the following step?
-

## Steps

1. Use cache from previous build
2. Delete and re-create cache
3. Use cache from previous step

## Instructions

- `swift package init --type executable`
- `swift package resolve`
- `swift build`
- `swift run`
