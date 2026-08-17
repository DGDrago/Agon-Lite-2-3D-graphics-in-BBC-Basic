# Agon Light 2 — 3D Graphics in BBC BASIC

**The imperative: a smooth, real-time 3D animation of the Cobra Mk III from *Elite*, using nothing but Agon's BBC BASIC. No assembler routines.**

The question we set out to answer was whether an interpreted BASIC — the one that ships with the machine — can do it at a frame rate you would not be embarrassed to show someone. Turned out it can... sort of... Namely, only using precomputed ("baked") coords for vertices, meaning - not exactly interactive experience.

In several iterations we went from 7.5 fps to a locked 30 fps. This document is the record of how-to and obstacles and quirks that Agon implementation of BBC Basic puts before its users.

---

## Table of contents

* [The result](#the-result)
* [The subject: Cobra Mk III](#the-subject-cobra-mk-iii)
* [Part 1 — What BBC BASIC on Agon actually costs](#part-1--what-bbc-basic-on-agon-actually-costs)
* [Part 2 — The frame budget, and two traps](#part-2--the-frame-budget-and-two-traps)
* [Part 3 — The optimisations, in the order we found them](#part-3--the-optimisations-in-the-order-we-found-them)
* [Part 4 — Hard limits: what the machine will and will not do](#part-4--hard-limits-what-the-machine-will-and-will-not-do)
* [Files](#files)
* [Running it](#running-it)

---

## The result

Every measurement below was taken on the Fab Agon Emulator with the CPU throttled to real Agon speed, and confirmed on screen.

|Stage|What changed|Displayed|Actual|
|-|-|-:|-:|
|1|Full 3×3 matrix, perspective divide, all 38 edges drawn|6–7|**7.5**|
|2|Mirror symmetry + orthographic projection|8–9|**10**|
|3|Hidden-edge removal via bitmask, hex constants|9–10|**~12**|
|4|Vertex loop unrolled|12|**15**|
|5|Orientations pre-baked into VDP buffers|24|**30**|

"Displayed" is what our on-screen counter said. "Actual" is the truth — see [the TIME trap](#trap-2-time-runs-20-fast). Every actual figure is an exact divisor of 60, which is not a coincidence; see [VSYNC quantisation](#trap-1-you-only-get-60n).

Stages 1–4 are genuine real-time 3D: the ship can rotate freely about any axis, and every vertex is transformed every frame. **15 fps is the practical ceiling for that.** Stage 5 trades freedom for speed — the rotation is pre-computed — and that is what buys 30 fps.

---

## The subject: Cobra Mk III

28 vertices, 38 edges, 13 faces. Of the 28 vertices, **4 sit on the centreline and 24 form 12 mirror pairs** — a fact we later turned into a 45% cut in multiplications.

After backface culling, the number of edges actually drawn averages between **20 and 27** depending on which orientations you pass through — 26.9 along the tumbling path taken by the real-time program, with a minimum of 11 when the ship is edge-on and a maximum of 36.

---

## Part 1 — What BBC BASIC on Agon actually costs

This is the section to read if you are optimising anything on this machine. We measured it rather than guessed, and several results were surprising.

Method: 5000 iterations of a one-statement loop, empty-loop time subtracted. The middle column is the raw figure in `TIME` units; the right-hand column converts to microseconds per operation (see [the TIME trap](#trap-2-time-runs-20-fast) for why the conversion is what it is).

### Cost of the basic operations

|Statement|per 5000|µs per op|vs. plain assignment|
|-|-:|-:|-|
|empty `FOR` iteration|28|47|—|
|`A%=B%`|28|47|baseline|
|`A%=B%+C%`|46|77|+30 µs|
|`A%=B%-C%`|46|77|+30 µs|
|`A%=Z%(3)` — array read|66|110|**+63 µs**|
|`Z%(3)=B%` — array write|66|110|**+63 µs**|
|`A%=B%*C%`|84|140|**+93 µs**|
|`A%=B% DIV C%`|96|160|**+113 µs**|
|`A%=B% DIV 256`|116|193|**+147 µs**|
|`A%=B%*C%+D%*E%`|158|263|+217 µs|

**Read this carefully, because the obvious conclusion is wrong.** Yes, multiplication is roughly three times an addition. But an *array access* costs two thirds of a multiply, and in a typical vertex loop you do more array accesses than multiplies. When we halved the multiplications and the frame time barely moved, this table is why.

The other thing to notice: the flat cost of *being a statement at all* is 47 µs. On an 18.4 MHz eZ80 that is roughly 900 cycles to do nothing but dispatch. Statement count matters as much as what the statements contain.

### The literal trap

This one we did not see coming.

|Expression|per 5000|
|-|-:|
|`A%=C%` (variable)|28|
|`A%=&FF` (hex constant)|**28**|
|`A%=255` (decimal constant)|46|
|`B%+C%`|48|
|`B%+160`|66|
|`B%*C%` / `B%*256`|84 / 102|
|`B% DIV C%` / `B% DIV K%` / `B% DIV 256`|96 / 96 / 114|

A **decimal literal costs the same as an extra variable operand** — about 30 µs each time it is evaluated. BBC BASIC stores numeric literals as text in the tokenised program and re-parses them on *every* execution.

A **hexadecimal literal is free** — indistinguishable from a variable reference.

So `DIV 256` is measurably slower than `DIV C%`, and `DIV &100` is as fast as either. In an inner loop, write your constants in hex. It costs nothing and it is the cheapest optimisation in this entire document.

### Variable name lookup

|Access|per 5000|
|-|-:|
|`A%=B%` (first variable on `B`)|28|
|`A%=M0%` (first of nine on `M`)|32|
|`A%=M8%` (ninth of nine on `M`)|48|

BBC BASIC keeps variables in a linked list per first letter and walks it. Nine variables named `M0%`…`M8%` means the last one is 50% dearer to reach than the first. Measured, this was worth about 0.1 cs per frame for us — real, but the smallest fish in the pond. Worth knowing if you have a hot loop touching many similarly-named variables.

---

## Part 2 — The frame budget, and two traps

### Trap 1: you only get 60/n

In a double-buffered mode, `VDU 23,0,&C3` swaps buffers **at the next vertical sync**. At 60 Hz your frame rate can therefore only be 60, 30, 20, 15, 12, 10, 8.6, 7.5 … and nothing in between.

The practical consequence is that optimisation is a **step function**. Shaving 15% off your frame time usually changes nothing at all, and then one more small saving suddenly moves you a whole step. Do not judge a change by whether the counter moved; judge it by the measured cost of what you removed.

Every one of our results — 7.5, 10, 15, 30 — is a divisor of 60. That is the shape of the problem.

### Trap 2: TIME runs 20% fast

From `MOS-API.md`:

> `sysvar_time: EQU 00h ; 4: Clock timer in centiseconds (incremented by 2 every VBLANK)`

Two units per VBLANK is arithmetic for a **50 Hz** machine: 2 × 50 = 100 units per second. Agon's 60 Hz screen modes tick `TIME` **120 times a second**. Every duration you measure with `TIME` in a 60 Hz mode is therefore 20% too large, and every rate you derive from it is 20% too small.

Our on-screen counter read 24 when the program was genuinely running at 30. Correct for it:

```basic
F$=STR$(1920 DIV (TIME-T0%+1))+" fps"   : REM 1600 would be the 50 Hz figure
```

We only caught this because 24 is not a divisor of 60 and that bothered us. Four earlier readings — 6–7, 8–9, 12, 24 — all snapped onto the 60/n ladder once multiplied by 1.2. If your frame rate is not landing on a divisor of the refresh rate, suspect your clock before you suspect your code.

---

## Part 3 — The optimisations, in the order we found them

### 1. Integer fixed point and a sine table

Floating point is not an option. Everything runs in integers with 8 fractional bits: the sine table holds `INT(256*SIN(...))` for 64 angles, and products are brought back down with `DIV &100`.

64 entries is a 5.6° step, which is smooth enough that the eye does not see it.

### 2. Mirror symmetry — 8 multiplications per pair instead of 16

The Cobra is symmetric about its centreline. For a vertex `(x,y,z)` and its mirror `(-x,y,z)`, the rotated coordinates share every term that does not involve `x`:

```
rx  =  a + z*M2        rx' = -a + z*M2         where a = x*M0
ry  =  b + y*M4 + z*M5 ry' = -b + y*M4 + z*M5        b = x*M3
```

Compute the shared part once, then add and subtract. Two vertices for the price of one and a bit. Across 24 of the 28 vertices this removed 45% of the multiplications.

**Applicability:** almost every spaceship, aircraft, car and building is mirror-symmetric. This is close to free real estate.

### 3. Orthographic projection — better than we expected

Dropping the perspective divide was supposed to save two divisions per vertex. It saved much more, because **without perspective you never need `z` at all**. The entire third row of the rotation matrix disappears from the vertex loop (it is still needed for backface culling, but that is 13 faces, not 28 vertices).

And the projection scale folds into the division that had to happen anyway to undo the 8 fractional bits:

```basic
SX%(J%)=&A0+(E%+A%) DIV DV%
```

One division, no multiplication, scale included. Combined with symmetry this took multiplications per frame from 224 to **72**, and divisions from 140 to **56**.

At a viewing distance where the ship spans a third of the screen, nobody can tell the difference. Keep perspective as a toggle if you want it; ours is on the `O` key and costs about a third of the frame rate.

### 4. Backface culling — the cheap way

*Elite*'s own method: every edge belongs to two faces, and an edge is drawn only if at least one of its faces points at the viewer.

The naive implementation rotates all 13 face normals with the full matrix — 104 multiplications, more than the vertices cost. But the test only needs the **z component** of the rotated normal, which is the dot product with the third row of the matrix:

```basic
IF NX%(I%)*M6%+NY%(I%)*M7%+NZ%(I%)*M8%<0 THEN ... visible
```

Three multiplications per face, 39 in total, and no division because only the sign matters.

Culling roughly halves the edges drawn (38 → 26.9 average) but costs about as much as it saves. **Do it for the look, not for the speed** — the ship stops being a transparent tangle and starts looking solid.

### 5. Visibility as a bitmask — one array read per edge instead of four

The obvious way to test an edge is `VI%(EF%(I%))<0 OR VI%(EG%(I%))<0`. That is four array reads per edge, two of them nested, 152 per frame — and by the table above, array reads are expensive.

Instead, build a 13-bit mask of visible faces once per frame, and give each edge a pre-computed mask of its own two faces:

```basic
REM once per frame
VB%=0
FOR I%=0 TO NF%-1
  IF NX%(I%)*M6%+NY%(I%)*M7%+NZ%(I%)*M8%<0 THEN VB%=VB% OR PW%(I%)
NEXT

REM per edge
IF (VB% AND EM%(I%)) THEN MOVE ... : DRAW ...
```

`EM%()` is built at load time and never changes. One array read replaces four; 114 array accesses vanish from every frame.

### 6. Hex constants everywhere

See [the literal trap](#the-literal-trap). `160` became `&A0`, `120` became `&78`, `256` became `&100`, `63` became `&3F`. Mechanical, zero risk, free.

### 7. Unrolling the vertex loop

With the geometry baked into the code as hex constants, the whole loop apparatus disappears — no loop counter, and above all no array reads to fetch each vertex:

```basic
 1000 A%=&20*M0% : B%=&20*M3%
 1010 E%=&4C*M2% : F%=&4C*M5%
 1020 SX%(&0)=&A0+(E%+A%) DIV DV% : SY%(&0)=&78-(F%+B%) DIV DV%
 1030 SX%(&1)=&A0+(E%-A%) DIV DV% : SY%(&1)=&78-(F%-B%) DIV DV%
```

Five array reads and one loop iteration removed per vertex pair. It also removes work we had not thought about: where a coordinate is zero, the term is simply not emitted. Vertex 20 is `(0,0,76)`, so `F%=0*M4%+&4C*M5%` becomes `F%=&4C*M5%`.

The code is ugly and long. **Generate it with a script** — ours is produced by a Python generator that also verifies, by parsing the emitted BASIC back, that all 28 vertices match the reference table. Never hand-type 56 lines of constants.

This took us from 12 to 15 fps and is where the real-time approach runs out of road.

### 8. Pre-baked orientations in VDP buffers — the step to 30 fps

The Buffered Commands API lets you store a sequence of VDU commands on the VDP and execute it later:

```basic
VDU 23,0,&A0,id;0,length;    : REM followed by <length> bytes, captured into the buffer
VDU 23,0,&A0,id;1            : REM execute everything in that buffer
```

So: at startup, compute all 64 rotational positions, and for each one write a buffer containing the screen clear and a `MOVE`/`DRAW` pair for every visible edge. From then on, an entire frame is:

```basic
VDU 23,0,&A0,BI%+A%;1
VDU 23,0,&C3
```

**Six bytes to draw the ship, six to swap buffers.** Neither the geometry nor the drawing touches the eZ80 any more. The limit becomes VSYNC.

Baking costs about 67 ms per position — 64 positions in roughly four seconds, with a progress display.

The cost is honesty about what you have built: this is a *recorded* rotation, not a free one. See [the multi-axis arithmetic](#multi-axis-the-real-constraint-is-patience-not-memory) for what it takes to add axes.

### 9. Clear only the bounding box

The full-screen clear is one `PLOT 101` — trivial for the eZ80, but 76,800 pixels of work for the VDP, every frame.

Measure the box the ship actually occupies across all orientations and clear only that. For our single-axis spin it is 229×126 = 28,854 pixels, **2.7× less fill**. The program measures it at startup rather than hard-coding it, so it stays correct if you change the scale or the pitch.

For a two-axis tumble the box grows to roughly 219×219 and the saving drops to about 1.6×.

### 10. Double buffering

`MODE 136` is 320×240 in 64 colours, double-buffered. `VDU 23,0,&C3` swaps. Without it, erasing and redrawing in the visible buffer tears and flickers badly at these frame rates.

Note that in a *non*-buffered mode the same command means "wait for VSYNC", which is useful in its own right.

---

## Part 4 — Hard limits: what the machine will and will not do

### The eZ80 side

Add up the measured costs of the irreducible work in a real-time frame — 72 multiplications, 56 divisions, 56 array writes, ~112 statements in the vertex code, 13 face tests, 38 edge tests, ~27 line draws, plus loop and housekeeping — and you land at roughly 6.6 `TIME` units per frame. That is four VSYNCs. **15 fps is the floor for free real-time 3D of a 28-vertex object in this BASIC**, and we are sitting on it.

30 fps needs the frame inside 3.33 units, which is below the cost of the arithmetic alone. There is no clever rewrite that gets there. The only way past is to stop computing per frame — which is exactly what stage 5 does.

BASIC's own memory is not a constraint. Measured on `bbcbasic24.bin`:

```
PAGE  = &44E00      HIMEM = &B0000
HIMEM-LOMEM = 438,465 bytes free
```

The often-quoted "64K segment, about 48K for programs" applies to the **8-bit `bbcbasic.bin`**, not the 24-bit ADL build. If you are using `bbcbasic24.bin` you have well over 400 KB.

### The VDP side

The VDP is an ESP32-Pico-D4 with **8 MB** of attached RAM. Screen memory for a double-buffered 320×240 mode is about 154 KB of that. Memory on the VDP is, for our purposes, unlimited.

There is **no command to query free VDP memory**. The commands that return data to the eZ80 are `&80`–`&89`: general poll, keyboard locale, cursor position, character at position, pixel colour, audio status, screen dimensions, RTC, keyboard control, mouse. Nothing about memory. If you exhaust it, you find out because things silently stop working.

The Buffered Commands API is generous: **65534 buffers**, a single block up to **65535 bytes**, and buffers may exceed 64 KB by holding several blocks (which is why the API has a 24-bit "advanced offset" mode).

### Why you cannot offload the maths to the ESP32

This is the question everyone asks, and the answer is no. Three reasons, in increasing order of finality:

1. **FabGL has nothing to offer.** The VDP runs a fork of FabGL (vdp-gl). It is a *2D* VGA library: lines, rectangles, circles, sprites, bitmaps, scrolling. There is no 3D pipeline, no matrix arithmetic, no vertex transform. There is no function to call.
2. **There is no way to call it.** The only interface from the eZ80 is the VDU command set. There is no mechanism to run arbitrary code on the ESP32 — short of modifying the `agon-vdp` firmware, at which point your program no longer runs on anyone else's machine.
3. **The one thing that looks like a processor on the VDP cannot multiply.** The Buffered Commands API has arithmetic (command 5) and control flow (conditional calls and jumps, commands 6, 7, 9–12) — a small virtual machine, in effect. Its complete operation set is:

> `0 NOT · 1 Negate · 2 Set · 3 Add · 4 Add with carry · 5 AND · 6 OR · 7 XOR`

No multiply, no divide, no shift. Rotation is multiplication. Building one out of repeated addition means up to 256 operations per multiply and 72 multiplies per frame — around 18,000 VDU operations per frame, orders of magnitude slower than letting the eZ80 do it.

Searching the whole documentation set for `affine`, `transform`, `matrix` and `rotate` returns nothing. This VDP does not even have a 2D affine transform for bitmaps.

**One thing you *can* offload that we did not need:** command 5 with the "multiple targets" bit can add a constant to a run of bytes inside a stored command sequence. That means the coordinates of a baked frame can be **translated** without re-baking. Rotation no, movement across the screen yes, almost free. If your ship needs to fly rather than spin in place, that is the mechanism.

### The link budget

The eZ80 talks to the VDP over an internal UART at **1,152,000 baud** — about 115,200 bytes per second.

A line is `MOVE` + `DRAW`, six bytes each, so **12 bytes per line** and a ceiling of roughly **9,600 lines per second**.

At 30 fps with 26.9 visible edges we send 806 lines per second: **8% of the link**. It was never close to being the bottleneck. If you are wondering whether to worry about the serial link, the answer is almost certainly no — worry about statement count in BASIC instead.

### Multi-axis: the real constraint is patience, not memory

Pre-baking is a product, not a sum. These are the real figures from `bake.py`, not estimates:

|Grid|Step|Positions|Avg edges|VDP memory|File|Load time|
|-|-|-:|-:|-:|-:|-:|
|64 × 1|5.6°, fixed tilt|64|19.7|16 KB|16,647 B|<1 s|
|32 × 16|11.25° / 22.5°|512|22.1|142 KB|147,968 B|~1.5 s|
|32 × 32|11.25°|1024|22.6|290 KB|302,680 B|~3 s|
|64 × 32|5.6° / 11.25°|2048|22.9|586 KB|612,160 B|~6 s|
|64 × 64|5.6°|4096|23.2|1.16 MB|1,236,336 B|~12 s|

All of these fit in 8 MB without difficulty. What does not fit is the user's patience if you compute them on the Agon: baking is about 67 ms per position, because BASIC must transform 28 vertices, test 13 faces and emit sixty-odd VDU statements for each one. A full 64 × 64 grid would take four and a half minutes.

So the orientations are **baked off-machine and shipped as data files**. The player programs never compute geometry at all — they open the file and pour it into the VDP. Load time is then governed by the serial link, and the figures above are what that works out to.

### The data file format

Repeated once per orientation:

```
"<payload length in decimal>" CR
<payload, in chunks of at most 200 bytes, each chunk followed by CR>
```

The payload is a ready-made VDU sequence: `GCOL` and a filled rectangle for the clear, then `MOVE`/`DRAW` for each visible edge.

The reason for the decimal length line and the CR chunk terminators is throughput. `INPUT#` returns raw bytes up to a CR, so it moves **200 bytes per BASIC statement**; `BGET#` moves one. Over a 1.2 MB file that is the difference between seconds and minutes.

The catch is that byte 13 must never appear inside a payload, or `INPUT#` would cut a chunk short and everything after it would desynchronise. `bake.py` guarantees this by nudging any coordinate whose low byte would be 13 by a single pixel — invisible on screen — and asserts on the result. Command bytes (18, 25, 4, 5, 101, 0, 1) and coordinate high bytes (0 or 1) can never be 13 anyway.

The player side is nine lines:

```basic
FOR N%=0 TO NPOS%-1
  INPUT#G%,A$ : L%=VAL(A$)
  VDU 23,0,&A0,BI%+N%;2
  VDU 23,0,&A0,BI%+N%;0,L%;
  FOR C%=1 TO (L%+199) DIV 200
    INPUT#G%,A$ : PRINT A$;
  NEXT
NEXT
```

After the `0,L%;` header the VDP swallows exactly `L%` bytes as data, so everything `PRINT` emits lands in the buffer instead of on the screen.

---

## Files

### Real-time

|File|What it is|
|-|-|
|`COBRA.BAS`|Real-time 3D. Free rotation about two axes, ~15 fps. Orthographic by default, perspective on `O`, hidden-edge removal on `H`. The vertex loop is machine-generated and unrolled.|
|`COBRA2.BAS`|Pre-baked single-axis rotation, but computed on the Agon at startup rather than loaded from a file. Four seconds of baking, then 30 fps. Kept because it is the shortest complete demonstration of the buffer technique.|

### Pre-baked, loaded from data

Each player is the same program with different grid constants. Pick one by how smooth you want it and how long you are prepared to wait for the load.

|Program|Data file|Positions|Rotation|
|-|-|-:|-|
|`COBRA_64x1.BAS`|`COBRA_64x1.VDU`|64|one axis, 5.6° steps, fixed tilt|
|`COBRA_32x16.BAS`|`COBRA_32x16.VDU`|512|two axes, 11.25° / 22.5°|
|`COBRA_32x32.BAS`|`COBRA_32x32.VDU`|1024|two axes, 11.25°|
|`COBRA_64x32.BAS`|`COBRA_64x32.VDU`|2048|two axes, 5.6° / 11.25°|
|`COBRA_64x64.BAS`|`COBRA_64x64.VDU`|4096|two axes, 5.6°|

### Tools and benchmarks

|File|What it is|
|-|-|
|`bake.py`|The generator. Produces every `.VDU` file. Run it **only when the geometry changes** — the data files are the deliverable and the players never regenerate them. It carries the same integer arithmetic as the BASIC, so what it bakes is bit-for-bit what the real-time version would have drawn.|
|`BENCH.BAS`|Frame-cost benchmark: full 3×3 rotation with perspective, single-axis without, line drawing, table lookup.|
|`LINES.BAS`|Line-throughput benchmark: `MOVE`/`DRAW` from BASIC versus raw VDU bytes streamed through `PRINT`.|
|`sim3.png`|Reference render of the geometry and the culling, produced by simulating the exact integer arithmetic off-machine.|

The average visible-edge count differs slightly between grids because it depends on the viewing angles sampled: 19.7 for the single-axis spin at its fixed tilt, 22–23 for the tumbling grids, and 26.9 along the particular animation path taken by the real-time `COBRA.BAS`.

### On testing an integer pipeline

Every version in this repo was verified by **re-implementing the exact integer arithmetic in Python** — same fixed-point, same truncation-toward-zero for `DIV` — and rendering the result to a PNG before a line of BASIC was run. That is how we caught a bad decoding of the ship data, confirmed the culling sign convention, and checked the unrolled code. On a machine where you cannot single-step and cannot printf your way through a frame, an off-machine reference implementation is worth more than any amount of staring at the screen.

---

## Running it

```
cd /games/Elite3D
load /bin/bbcbasic24.bin
run . cobra.bas          : REM real-time, free rotation, ~15 fps
run . cobra_64x1.bas     : REM pre-baked, 30 fps, loads in under a second
run . cobra_64x64.bas    : REM pre-baked, 30 fps, smoothest tumble, ~12 s load
```

`bbcbasic.bin` works too, provided the `.BAS` files keep their CRLF line endings.

Controls are listed in the header comment of each program. Broadly: `Q` quits, `SPACE` pauses, `+` and `-` change distance or speed.

Regenerating the data files, only ever needed if the geometry changes:

```
python bake.py
```

### If a pre-baked player shows a black screen

There is no way to ask the VDP how much memory is free, and it reports nothing when an allocation fails, so a black screen is the symptom of running out. Drop to a smaller grid. The 64 × 1 variant needs 16 KB and will run on anything.

---

## What we did not do

* **Perspective at 30 fps.** The pre-baked path could store perspective-projected positions just as easily; we left it orthographic.
* **Clipping.** The ship is scaled to stay on screen. Move it or zoom in far enough and coordinates will run off the edges.
* **More than one ship.** `elite.bin` contains blueprints for 29 of them, and the header table at offset 61151 gives the vertex, edge and face counts for each. Extracting another is mostly a matter of the same cross-validation exercise.
* **Filled polygons.** The VDP has triangle fill (`PLOT 80–87`). A solid-shaded Cobra with depth sorting would be a different and considerably harder project — but the face normals needed for it are already in the data.

