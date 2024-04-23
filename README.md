# DiRTOS
Real-time operating system excercise. Target is a poorly supported riscv32 
architecture on a SiFive Freedom chip. The original goal was to write a scheduler
that is based upon Zig's aync/await system. While fron the inception it was promising,
the future of aync/await is unclear, and progress was slow due to encountering issues
with the linker and bad instructions being emitted occasionally, among other things.
That architecture is Tier 4 support at the time of writing afterall. 

Therfore this project is **abandoned**.
