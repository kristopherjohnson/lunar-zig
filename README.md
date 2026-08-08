# LUNAR for Zig

This is a port of the classic text-based ["lunar lander" game][lunarlander] to [Zig][zig].

The original Lunar Lander program was written by Jim Storer in the FOCAL programming language in 1969. This repository ports the code to idiomatic Zig 0.16, providing a clear learning example of command-line I/O, floating-point physics simulation, and test automation in Zig.

## Requirements

* [Zig][zig] (0.16.0 or newer)

## Building and Running

To build and run the executable interactively:

```bash
zig build run
```

Or to build the executable (`zig-out/bin/lunar`):

```bash
zig build
./zig-out/bin/lunar
```

## Running Tests

To run unit tests and the integration test suite (replicating all original `lunar-c` test cases):

```bash
zig build test
```

## Game Play Example

```
CONTROL CALLING LUNAR MODULE. MANUAL CONTROL IS NECESSARY
YOU MAY RESET FUEL RATE K EACH 10 SECS TO 0 OR ANY VALUE
BETWEEN 8 & 200 LBS/SEC. YOU'VE 16000 LBS FUEL. ESTIMATED
FREE FALL IMPACT TIME-120 SECS. CAPSULE WEIGHT-32500 LBS


FIRST RADAR CHECK COMING UP


COMMENCE LANDING PROCEDURE
TIME,SECS   ALTITUDE,MILES+FEET   VELOCITY,MPH   FUEL,LBS   FUEL RATE
      0             120      0        3600.00     16000.0      K=:0
     10             109   5016        3636.00     16000.0      K=:0
...
ON THE MOON AT   170.88 SECS
IMPACT VELOCITY OF     0.61 M.P.H.
FUEL LEFT:   459.78 LBS
PERFECT LANDING !-(LUCKY)
```

## License

This project is dedicated to the public domain under the [CC0 1.0 Universal License](LICENSE).

[lunarlander]: https://en.wikipedia.org/wiki/Lunar_Lander_(video_game_genre)#Text_games
[zig]: https://ziglang.org/

