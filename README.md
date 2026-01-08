# arbys-coreutils

Collection of, _UNIX_ based; *file*, *shell* and *text manipulation* utilities, written in _*Zig*_. 

This is a work in progress.

## Available Utilities
- rmdir
- echo (incomplete)
- yes (needs memory fixes)
- hostname (no flags)
- true
- false

## Build
### Dependencies
- zig 0.15.2

### Steps
```bash
# to build all of the utils
$ zig build -p <output_directory>

# to build individual utils
$ zig build -p <output_directory> -Dutilname=<util_name>

# to run the tests
$ zig test <path_to_src_file>
```
