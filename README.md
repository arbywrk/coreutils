# coreutils

A reimplementation of the *GNU coreutils* in _*Zig*_. This is a work in progress.

## Build
### Dependencies
- zig 0.15.x

### Steps
```bash
# to build all of the utils
$ zig build -p <output_directory>

# to build individual utils
$ zig build -p <output_directory> -Dutilname=<util_name>
```
