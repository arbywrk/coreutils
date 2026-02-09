# arbys-coreutils

Small collection of UNIX-style file, shell, and text utilities written in Zig.

## Status
Early-stage: interfaces and coverage are evolving. Contributions welcome.

## Available Utilities
- rmdir
- echo (partial feature coverage)
- yes (memory usage improvements planned)
- hostname (basic output only)
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

## Roadmap
- Add more tests
- Implement more utils
