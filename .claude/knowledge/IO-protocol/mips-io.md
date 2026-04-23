# MIPS Architecture IO Protocol Reference

> **Document Type**: IO Protocol Knowledge Reference
> **Target Audience**: Digital IC Design Architects
> **Version**: v1.0
> **Date**: 2026-04-15

---

## 1. MIPS Architecture Overview

MIPS (Microprocessor without Interlocked Pipeline Stages) is a RISC ISA family developed by MIPS Technologies. This document focuses on the **IO protocol and bus interface** aspects relevant to SoC integration and peripheral design.

### 1.1 MIPS Generations Relevant to IO Design

| Generation | Era | IO Bus | Typical Use |
|---|---|---|---|
| MIPS I/II | 1980s-90s | SBus, VME | Workstations |
| MIPS III/IV | 1990s | GBus, SysAD | SGI systems |
| MIPS32/MIPS64 | 2000s+ | AHB, OCP, AXI | Embedded SoC |
| MIPS microAptiv | 2010s | AHB-Lite, APB | MCU-class |
| MIPS interAptiv | 2010s | AHB, AXI | Multi-core SoC |
| MIPS proAptiv | 2010s | AXI, OCP | High-perf SoC |
| MIPS I-class | 2020s | AXI4, ACE | AI/networking |

### 1.2 System-Level IO Topology

```
+------------------------------------------------------------------+
|                         MIPS SoC                                  |
|                                                                   |
| +-----------+    +---------+    +----------+    +-------------+   |
| | MIPS Core |<-->| L2 Cache|<-->| Bus Fabric|<-->| Memory Ctrl |   |
| | (Coherent)|    | (Opt.)  |    | (AXI/AHB) |    | (DDR/LPDDR)|   |
| +-----------+    +---------+    +-----+------+    +-------------+   |
|      ^                               |                             |
|      | Coherence               +-----+-----+                      |
|      | (ACE/CHI)               |           |                      |
| +----+------+          +-------+--+  +-----+------+               |
| | Snoop Ctrl|          | AXI-to-  |  | AHB-to-APB |               |
| | (MIPS CM) |          | AHB Bridge| | Bridge     |               |
| +-----------+          +----+-----+  +-----+------+               |
|                             |              |                       |
|                        +----+----+   +-----+-----+                |
|                        | DMA Eng |   | UART/SPI  |                |
|                        +---------+   | I2C/GPIO  |                |
|                                      | Timer/Int |                |
|                                      +-----------+                |
+------------------------------------------------------------------+
```

---

## 2. Coherence Manager (CM) — IO Coherence Interface

The MIPS **Coherence Manager** (CM) is the central hub for IO device coherence. It provides two key interfaces for IO agents.

### 2.1 CM Block Diagram

```
                     +---------------------------+
                     |      MIPS Coherence       |
                     |        Manager (CM)        |
                     |                            |
  +--------+        |  +--------+  +--------+    |        +-----------+
  | Core 0 |<------>|  | L2 Slice|  | Snoop  |    |<------>| IO Bridge |
  +--------+  CCA   |  +--------+  | Filter |    |  IOCB  +-----------+
  +--------+        |              +--------+    |
  | Core 1 |<------>|  +-------------------+     |        +-----------+
  +--------+  CCA   |  | Global Directory  |     |<------>| DMA Engine|
  +--------+        |  | (GIC - Optional)  |     |  IOCB  +-----------+
  | Core N |<------>|  +-------------------+     |
  +--------+  CCA   |                            |
                     |  +-------------------+     |        +-----------+
                     |  | Memory Controller |     |<------>| PCIe Root |
                     |  | Interface         |     |  IOCB  +-----------+
                     |  +-------------------+     |
                     +---------------------------+
                              |
                        +-----v-----+
                        |   System  |
                        |   Memory  |
                        +-----------+

CCA  = Cache Coherency Attribute bus (from cores)
IOCB = IO Coherency Bus (from IO agents)
```

### 2.2 IO Coherency Bus (IOCB)

The IOCB is the primary IO-facing interface of the CM. It allows IO devices to participate in the cache coherency protocol.

| Signal Group | Direction | Description |
|---|---|---|
| `iocb_req` | IO → CM | Read/Write/Atomic request |
| `iocb_addr` | IO → CM | Physical address (up to 40-bit) |
| `iocb_size` | IO → CM | Transfer size (1B to 64B) |
| `iocb_cmd` | IO → CM | Command: Rd, RdEx, Rd_Shared, Wr, WrInv, Atomic |
| `iocb_wdata` | IO → CM | Write data |
| `iocb_resp` | CM → IO | Response: Ack, Data, Error |
| `iocb_rdata` | CM → IO | Read data |
| `iocb_rdata_valid` | CM → IO | Read data valid |
| `iocb_snoop` | CM → IO | Snoop request to IO (for dirty data) |
| `iocb_snoop_resp` | IO → CM | Snoop response: Hit, Miss |
| `iocb_snoop_data` | IO → CM | Snoop data (dirty eviction) |

**IOCB Commands**:

| Command | Code | Description |
|---|---|---|
| `IOCB_RD` | 0x0 | Non-coherent read |
| `IOCB_RDEX` | 0x1 | Read Exclusive (for subsequent write) |
| `IOCB_RDSH` | 0x2 | Read Shared (coherent, cacheable) |
| `IOCB_WR` | 0x4 | Non-coherent write |
| `IOCB_WRINV` | 0x5 | Write Invalidate (coherent write-back) |
| `IOCB_ATOMIC` | 0x6 | Atomic operation (LL/SC or CAS) |
| `IOCB_PREFETCH` | 0x7 | Prefetch hint |

### 2.3 Coherency Attributes (CCA)

IO transactions carry CCA bits that determine coherency behavior:

| CCA Value | Name | Coherent | Cached | Prefetchable | Typical Use |
|---|---|---|---|---|---|
| `0x0` | UC (Uncached) | No | No | No | MMIO registers |
| `0x2` | UCE (Uncached Accelerated) | No | No | Yes | Frame buffer |
| `0x5` | WB (Write-Back) | Yes | Yes | Yes | DMA coherent buffers |
| `0x7` | WP (Write-Through) | Yes | Write-through | Yes | Shared config |
| `0x6` | WS (Write-Snooped) | Yes | Yes | Yes | IO coherent DMA |

**Key Rule**: IO DMA engines must program the correct CCA for each transaction. Using WB for MMIO registers causes unpredictable behavior.

---

## 3. System Bus Protocols

MIPS SoCs typically use AMBA-family buses. The choice depends on the core class.

### 3.1 AMBA AHB (Advanced High-performance Bus)

Used in MIPS microAptiv and simpler SoC designs.

```
AHB Master/Slave Connection for MIPS IO:

  +-----------+      +---------+      +-----------+
  | MIPS Core | AHB  | AHB     | AHB  | SRAM Ctrl |
  | (Master)  |----->| Arbiter |----->| (Slave)   |
  +-----------+      +----+----+      +-----------+
                           |
  +-----------+            |           +-----------+
  | DMA Ctrl  | AHB Master|      AHB  | Flash Ctrl|
  | (Master)  |-----------+---------->| (Slave)   |
  +-----------+                       +-----------+
                           |
                      +----v----+
                      | AHB-to-APB Bridge |
                      +----+----+
                           |
                      APB Bus → UART, SPI, I2C, GPIO, Timer
```

**AHB Signal Summary for IO Design**:

| Signal | Width | Direction | Description |
|---|---|---|---|
| `HCLK` | 1 | Input | Bus clock |
| `HRESETn` | 1 | Input | Active-low reset |
| `HADDR[31:0]` | 32 | M→S | Address bus |
| `HWDATA[31:0]` | 32 | M→S | Write data bus |
| `HRDATA[31:0]` | 32 | S→M | Read data bus |
| `HSIZE[2:0]` | 3 | M→S | Transfer size (1/2/4/8/16/32/64/128B) |
| `HBURST[2:0]` | 3 | M→S | Burst type (SINGLE/INCR/WRAP4/INCR4/...) |
| `HTRANS[1:0]` | 2 | M→S | Transfer type (IDLE/BUSY/NONSEQ/SEQ) |
| `HWRITE` | 1 | M→S | 1=Write, 0=Read |
| `HREADY` | 1 | S→M | Transfer complete (wait states) |
| `HRESP[1:0]` | 2 | S→M | Response (OKAY/ERROR/RETRY/SPLIT) |
| `HSELx` | 1 | Decoder | Slave select |
| `HMASTLOCK` | 1 | M→S | Locked sequence (atomic) |
| `HPROT[3:0]` | 4 | M→S | Protection: data/opcode, privileged/user, bufferable, cacheable |

**AHB Burst Encoding**:

| HBURST | Type | Beats | Notes |
|---|---|---|---|
| `000` | SINGLE | 1 | Single transfer |
| `001` | INCR | Unspecified | Incrementing, undefined length |
| `010` | WRAP4 | 4 | 4-beat wrapping burst |
| `011` | INCR4 | 4 | 4-beat incrementing burst |
| `100` | WRAP8 | 8 | 8-beat wrapping burst |
| `101` | INCR8 | 8 | 8-beat incrementing burst |
| `110` | WRAP16 | 16 | 16-beat wrapping burst |
| `111` | INCR16 | 16 | 16-beat incrementing burst |

**AHB Transfer Timing Example (32-bit write with wait states)**:

```
        ___     ___     ___     ___     ___
HCLK   |   |___|   |___|   |___|   |___|   |___
            |       |       |       |
Cycle:      T1      T2      T3      T4

HADDR    |<-- Valid Addr ------>|<-- Next Addr ---
HWDATA   |                       |<-- Write Data ->
HWRITE   |<-- 1 (Write) -------->|
HTRANS   |<-- NONSEQ ----------->|<-- IDLE ------
HREADY   |       |<-- 1 (T3) ---->|<-- 1 (T4) ---
HSIZE    |<-- 010 (Word) ------->|
HSELx    |<-- 1 (Slave Selected)>

T1: Address phase — master drives HADDR, HWRITE, HTRANS, HSIZE
T2: Wait state — slave not ready (HREADY=0)
T3: Data phase — slave accepts data (HREADY=1)
T4: Idle — master completes transfer
```

### 3.2 AMBA AXI4 (Advanced eXtensible Interface)

Used in MIPS interAptiv, proAptiv, and I-class designs.

**AXI4 Channel Structure**:

```
Master                              Slave
  |                                   |
  |--- Write Address (AW) ----------->|
  |--- Write Data (W) --------------->|
  |<-- Write Response (B) ------------|
  |                                   |
  |--- Read Address (AR) ------------>|
  |<-- Read Data (R) -----------------|
  |                                   |

5 independent channels, each with VALID/READY handshake:
  AW: awaddr, awlen, awsize, awburst, awcache, awprot, awid, awlock
  W:  wdata, wstrb, wlast, wid
  B:  bresp, bid, bvalid
  AR: araddr, arlen, arsize, arburst, arcache, arprot, arid, arlock
  R:  rdata, rresp, rlast, rid
```

**AXI4 vs AHB Feature Comparison**:

| Feature | AHB | AXI4 | AXI4-Lite |
|---|---|---|---|
| Channels | Shared bus | 5 independent | 5 independent |
| Burst length | 1-16 or unspecified | 1-256 | 1 only |
| Outstanding transactions | 1 (per master) | Up to 256 (ID-based) | 1 |
| Data width | 8-128 bit | 8-1024 bit | 32 or 64 bit |
| Atomic ops | Locked sequences | Locked sequences | No |
| QoS | No | Yes (AWQOS/ARQOS) | No |
| User signals | No | Yes (AWUSER/ARUSER) | No |
| Typical latency | 2-4 cycles | 2-5 cycles | 2-3 cycles |
| Area overhead | Low | Medium | Low |
| MIPS SoC use | microAptiv MCU | proAptiv, I-class | Register access |

**AXI4 Cache Attribute (AxCACHE) Mapping to MIPS CCA**:

| AxCACHE | MIPS CCA Equivalent | Description |
|---|---|---|
| `0000` | UC | Device Non-bufferable |
| `0001` | UC | Device Bufferable |
| `0010` | UC | Normal Non-cacheable Non-bufferable |
| `0011` | UC | Normal Non-cacheable Bufferable |
| `0110` | WP | Write-through No-allocate |
| `0110` | WP | Write-through Read-allocate |
| `1110` | WP | Write-through Write-allocate |
| `1110` | WP | Write-through Read/Write-allocate |
| `1010` | WB | Write-back No-allocate |
| `1110` | WB | Write-back Read-allocate |
| `1111` | WB | Write-back Write-allocate |
| `1111` | WB | Write-back Read/Write-allocate |

### 3.3 APB (Advanced Peripheral Bus)

Low-speed register access bus for UART, SPI, I2C, GPIO, Timers.

```
APB Bridge                        APB Slaves
+------------+    PCLK       +----------+
| AHB/APB    |--------------->| UART     | PSELx[0]
| Bridge     |    PADDR      +----------+
|            |--------------->| SPI      | PSELx[1]
| PADDR[15:2]|    PWDATA     +----------+
| PWDATA[31] |--------------->| I2C      | PSELx[2]
| PWRITE     |    PRDATA     +----------+
| PSELx[n:0] |<---------------| GPIO     | PSELx[3]
| PENABLE    |                +----------+
| PREADY     |--------------->| Timer    | PSELx[4]
+------------+                +----------+
```

**APB Transfer Timing (Write)**:

```
        ___     ___     ___     ___
PCLK   |   |___|   |___|   |___|   |___
           |       |       |
Setup      T1      T2     Access
Phase      |       |       |
PADDR  |<-- Valid Addr ---->|
PWDATA |<-- Valid Data ---->|
PWRITE |<-- 1 ------------->|
PSELx  |<-- 1 ------------->|
PENABLE|       |<-- 1 ----->|
PREADY |               |<-- 1
```

---

## 4. Interrupt Architecture

### 4.1 MIPS Interrupt Hierarchy

```
External Interrupt Sources
(Software, Timer, Hardware IRQ[5:0])
         |
         v
+-------------------+
| Coprocessor 0     |
| Cause/IP[7:0]     |  ← Interrupt Pending bits
| Status/IM[7:0]    |  ← Interrupt Mask bits
| Status/IE         |  ← Interrupt Enable (global)
| Status/EXL        |  ← Exception Level
+-------------------+
         |
         v
+-------------------+
| Priority Encoder  |  (Hardware, by convention:)
+-------------------+    IP[0] = Software Int 0 (highest)
         |                IP[1] = Software Int 1
         v                IP[2] = Hardware Int 0
+-------------------+    IP[3] = Hardware Int 1 (Timer)
| Exception Vector  |    IP[4] = Hardware Int 2
| (BEV=0: kseg0)   |    IP[5] = Hardware Int 3
| (BEV=1: kseg1)   |    IP[6] = Hardware Int 4
+-------------------+    IP[7] = Hardware Int 5 (lowest)
```

### 4.2 Interrupt Controller Options

#### 4.2.1 MIPS GIC (Global Interrupt Controller)

The GIC provides scalable interrupt management for multi-core MIPS systems.

```
                  +---------------------+
 HW_IRQ[7:0] ---->|                     |
 SW_IRQ[1:0] ---->|   MIPS GIC          |----> Core 0 Interrupt
                  |                     |----> Core 1 Interrupt
 HW_IRQ[255:8] -->|  - Routing          |----> Core N Interrupt
                  |  - Polarity          |
                  |  - Edge/Level        |----> IPI (Inter-Processor
                  |  - Masking           |     Interrupt)
                  |  - Priority          |
                  |  - Vectored          |----> Performance Counter
                  +---------------------+      Interrupt
```

**GIC Key Registers**:

| Register | Address Offset | Description |
|---|---|---|
| `GIC_SH_INT_ROUTE` | 0x2000+ | Per-interrupt routing to cores |
| `GIC_SH_INT_POL` | 0x0100 | Polarity (active-high/low) |
| `GIC_SH_INT_TRIG` | 0x0180 | Trigger (edge/level) |
| `GIC_SH_INT_MASK` | 0x0000 | Interrupt mask (shared) |
| `GIC_SH_INT_PEND` | 0x0080 | Interrupt pending (shared) |
| `GIC_VPE_LOCAL_*` | 0x3000+ | Per-VPE local interrupt control |
| `GIC_SH_MAP_TO_PIN` | 0x0400 | Map HW interrupt to IP pin |

#### 4.2.2 External Interrupt Controller (EIC / Vectored Mode)

For systems with an external interrupt controller (e.g., custom EIC or standard PLIC):

```
External IC (PLIC-style)
+--------------------+
| Source 0-255       |
| Priority[0-255]    |---|---> EIC_Referee ---> INT signal (IP[5])
| Threshold          |        (inside MIPS)
| Claim/Complete     |        Vec_Offset ---> Vector address
+--------------------+
```

**EIC Mode vs Standard Mode**:

| Feature | Standard (GIC) | EIC Mode |
|---|---|---|
| Interrupt source | Internal GIC | External controller |
| Number of sources | 256 (GIC) | Up to 2048 (PLIC) |
| Priority | GIC priority | External priority |
| Vector table | Software lookup | Hardware vectored |
| Latency | Higher (SW dispatch) | Lower (HW vector) |
| Scalability | Good for ≤256 IRQs | Good for >256 IRQs |

### 4.3 Interrupt Timing (Level-Triggered Example)

```
        ___     ___     ___     ___     ___     ___     ___
Clock  |   |___|   |___|   |___|   |___|   |___|   |___|   |___
           |       |       |       |       |       |
HW_IRQ     |<-- 1 (asserted, level) ------>|<- 0 (deasserted)
           |       |       |       |       |
Cause_IP   |       |       |<- 1 ----------+------->
           |       |       |       |       |
IE & ~EXL  |       |       |<- 1 (enabled)--------->
           |       |       |       |       |
Exception  |       |       |       |<- 1 ->|
           |       |       |       |       |
Vector     |       |       |       |<- Addr -------->
           |       |       |       |       |
ISR        |       |       |       |       |<- Entry ->
           |       |       |       |       |
Clear HW   |       |       |       |       |<- Device clears IRQ
IRQ        |       |       |       |       |  after ISR servicing
           |       |       |       |       |
ERET       |       |       |       |       |       |<- Return
```

---

## 5. DMA (Direct Memory Access) Architecture

### 5.1 DMA in MIPS SoC

```
+-------------------+          +-------------------+
|  MIPS Core        |          |   DMA Engine      |
|                   |          |                   |
|  +-------------+  |   AHB/   |  +-------------+  |
|  | L1 D-Cache  |  |   AXI    |  | Channel 0   |  |
|  | (Write-back)|  |<-------->|  | (Mem-to-Mem)|  |
|  +-------------+  |          |  +-------------+  |
|                   |          |  +-------------+  |
|  +-------------+  |          |  | Channel 1   |  |
|  | L2 Cache    |  |          |  | (IO-to-Mem) |  |
|  | (Optional)  |  |          |  +-------------+  |
|  +-------------+  |          |  +-------------+  |
|                   |          |  | Channel 2   |  |
+-------------------+          |  | (Mem-to-IO) |  |
                               |  +-------------+  |
+-------------------+          |                   |
|   System Memory   |          |  +-------------+  |
|   (DDR/LPDDR)    |<-------->|  | Descriptor  |  |
+-------------------+          |  | Fetch Engine|  |
                               |  +-------------+  |
+-------------------+          |                   |
|   Peripheral      |<-------->|  +-------------+  |
|   (SPI/UART/...)  |          |  | Interrupt   |  |
+-------------------+          |  | Generator   |  |
                               |  +-------------+  |
                               +-------------------+
```

### 5.2 DMA Channel Descriptor (Linked-List Mode)

```
Descriptor Format (32 bytes, typical):
+--------+--------+--------+--------+
| Source Addr    (32-bit)            |  Offset 0x00
+--------+--------+--------+--------+
| Dest Addr      (32-bit)            |  Offset 0x04
+--------+--------+--------+--------+
| Transfer Size  (32-bit)            |  Offset 0x08
+--------+--------+--------+--------+
| Control        (32-bit)            |  Offset 0x0C
|   [31:24] = Transfer Width         |
|   [23:16] = Burst Length           |
|   [15:8]  = Source CCA             |
|   [7:4]   = Dest CCA               |
|   [3]     = Source Increment       |
|   [2]     = Dest Increment         |
|   [1]     = Interrupt on Complete  |
|   [0]     = Link Valid             |
+--------+--------+--------+--------+
| Next Descriptor Addr (32-bit)      |  Offset 0x10
+--------+--------+--------+--------+
| User Data        (32-bit)          |  Offset 0x14
+--------+--------+--------+--------+
| Status           (32-bit)          |  Offset 0x18
|   [31]    = Complete               |
|   [30]    = Error                  |
|   [29:0]  = Bytes Transferred      |
+--------+--------+--------+--------+
| Reserved         (32-bit)          |  Offset 0x1C
+--------+--------+--------+--------+
```

### 5.3 DMA Coherency Considerations

**Critical for MIPS IO design**: DMA engines must handle cache coherency correctly.

| Scenario | Solution | CCA Setting | Cache Action Required |
|---|---|---|---|
| DMA read (device → memory, CPU reads later) | Write-back + Cache Flush | WB | CPU must Invalidate before reading |
| DMA write (memory → device, CPU wrote before) | Write-back + Cache Flush | WB | CPU must Writeback before DMA reads |
| Coherent DMA (no SW intervention) | Write-Snooped | WS | CM snoops automatically |
| Uncached DMA (small/infrequent) | Uncached | UC | No cache interaction |

**Software Sequence for Non-Coherent DMA**:

```c
// DMA Write (memory → device, CPU prepared the buffer)
cache_flush(buffer, size);    // Writeback dirty lines
dma_start(src=buffer, dst=device, size);  // CCA = UC for device

// DMA Read (device → memory, CPU will read the buffer)
dma_start(src=device, dst=buffer, size);  // CCA = UC for device
dma_wait_complete();
cache_invalidate(buffer, size);  // Invalidate stale cache lines
```

---

## 6. Memory-Mapped IO (MMIO) Design

### 6.1 MIPS Address Map

```
MIPS32 Virtual Address Space:
+------------------+ 0xFFFF_FFFF
| kseg3 (cached)   |  0xE000_0000 - 0xFFFF_FFFF  (Kernel, mapped)
+------------------+ 0xE000_0000
| ksseg (cached)   |  0xC000_0000 - 0xDFFF_FFFF  (Supervisor)
+------------------+ 0xC000_0000
| kseg1 (uncached) |  0xA000_0000 - 0xBFFF_FFFF  ← MMIO registers
+------------------+ 0xA000_0000
| kseg0 (cached)   |  0x8000_0000 - 0x9FFF_FFFF  ← DRAM, boot
+------------------+ 0x8000_0000
| useg (user)      |  0x0000_0000 - 0x7FFF_FFFF  ← User programs
+------------------+ 0x0000_0000

Physical Address Space (typical MIPS SoC):
+------------------+ 0xFFFF_FFFF
| Reserved         |
+------------------+ 0x1FFF_FFFF
| Peripheral Space |  0x1C00_0000 - 0x1FFF_FFFF  (APB devices)
+------------------+ 0x1C00_0000
| IO Bridge Space  |  0x1800_0000 - 0x1BFFF_FFFF  (AHB/AXI slaves)
+------------------+ 0x1800_0000
| Flash/ROM        |  0x1000_0000 - 0x17FF_FFFF
+------------------+ 0x1000_0000
| DDR Memory       |  0x0000_0000 - 0x0FFF_FFFF  (256MB example)
+------------------+ 0x0000_0000
```

### 6.2 MMIO Register Access Rules

| Rule | Description |
|---|---|
| Use kseg1 (uncached) | MMIO must never be cached — use 0xA000_0000+ mapping |
| Read side-effects | Reading a register may have side effects (e.g., FIFO pop, IRQ clear) — do not optimize away reads |
| Write ordering | Use `sync` instruction between writes to different registers if ordering matters |
| Atomic access | Use 32-bit aligned accesses; byte/halfword MMIO may not be supported |
| Barrier after write | `iowrite32(val, reg)` → includes `wmb()` or `sync` |
| Barrier before read | `ioread32(reg)` → includes `rmb()` or `sync` |

**Register Access Timing Constraint**:

```
MIPS Core                 Bus                    Peripheral
    |                      |                        |
    |-- Write REG_A ------>|                        |
    |                      |-- Addr + Data ------->|
    |                      |                        |-- Register updated
    |                      |<-- OKAY ---------------|
    |-- sync ------------>|                        |
    |                      |-- Barrier complete --->|
    |-- Write REG_B ------>|                        |
    |                      |-- Addr + Data ------->|
    |                      |                        |-- Register updated
                                  (REG_B write guaranteed after REG_A)
```

---

## 7. Bus Bridge and Interconnect Design

### 7.1 AHB-to-APB Bridge

The AHB-to-APB bridge connects high-speed AHB bus to low-speed APB peripherals.

```
AHB Side                      APB Side
+----------+                  +----------+
| HADDR    |--+               | PADDR    |
| HWDATA   |  |  +--------+  | PWDATA   |
| HRDATA   |<-+->| Bridge |->| PRDATA   |
| HWRITE   |  |  | FSM    |<-| PWRITE   |
| HSIZE    |--+  +--------+  | PSELx    |
| HREADY   |<---+            | PENABLE  |
| HRESP    |<---+            | PREADY   |
+----------+     +--------+  +----------+
                  | Decode |
                  | Logic  |
                  +--------+
```

**Bridge FSM**:

```
         +--------+
    +--->| IDLE   |<------------------+
    |    +---+----+                   |
    |        | HSEL & HTRANS=NONSEQ   |
    |        v                        |
    |    +--------+                   |
    |    | SETUP  | (PSEL=1, PADDR,  |
    |    +---+----+  PWDATA ready)    |
    |        |                        |
    |        v                        |
    |    +--------+                   |
    |    | ACCESS | (PENABLE=1)       |
    |    +---+----+                   |
    |        | PREADY=1               |
    |        v                        |
    |    +--------+                   |
    +----| DONE   | (HREADY=1)        |
         +--------+                   |
```

### 7.2 AXI-to-AHB Bridge

Used in systems with AXI master and AHB slave peripherals.

```
AXI Master                    Bridge                    AHB Slave
+----------+     +----------------------------+     +----------+
| AW Channel|---->| Write Data Buffer          |---->| HWDATA   |
| W Channel |---->| Write Addr Queue           |---->| HADDR    |
| B Channel |<----| Write Response Queue       |<----| HRESP    |
| AR Channel|---->| Read Addr Queue            |---->| HADDR    |
| R Channel |<----| Read Data Buffer           |<----| HRDATA   |
+----------+     +----------------------------+     +----------+

Key Challenges:
1. AXI out-of-order → AHB in-order: Reorder buffer needed
2. AXI burst → AHB burst: Burst translation (INCR16 → INCR16)
3. AXI narrow burst → AHB: Multiple AHB beats per AXI beat
4. Outstanding: AXI supports multiple outstanding; AHB may not
```

---

## 8. Clock, Reset, and Power Management for IO

### 8.1 Clock Domain Strategy

```
+-------------------+          +-------------------+
| MIPS Core Domain  |          | IO Domain         |
|                   |          |                   |
| Core_CLK          |          | IO_CLK            |
| (PLL0, 800MHz)   |          | (PLL1, 200MHz)   |
|                   |          |                   |
| +---------------+ |  Async   | +---------------+ |
| | L2 Cache      | |  Bridge  | | UART          | |
| | AHB/AXI fabric|<-+-------->| | SPI           | |
| +---------------+ |          | | I2C           | |
|                   |          | +---------------+ |
+-------------------+          +-------------------+

Clock Domains:
  1. Core_CLK  — CPU cores, L2 cache, coherent bus
  2. Bus_CLK   — Main system bus (AHB/AXI)
  3. IO_CLK    — Peripheral bus (APB), UART, SPI, I2C
  4. DDR_CLK   — Memory controller
  5. PHY_CLK   — External PHY (Ethernet, USB)
```

### 8.2 Reset Sequencing

```
Power On
   |
   v
POR (Power-On Reset) assertion
   |
   v
+--------+     +--------+     +--------+     +--------+
| PLL    |---->| Core   |---->| Bus    |---->| IO     |
| Reset  |     | Reset  |     | Reset  |     | Reset  |
| Release|     | Release|     | Release|     | Release|
| (t=0)  |     | (t=1ms)|     | (t=2ms)|     | (t=3ms)|
+--------+     +--------+     +--------+     +--------+

Reset Order: PLL → Core → Bus → IO (upstream first)
Deassert order is bottom-up: IO → Bus → Core → PLL
(Actually: PLL locked first, then everything deasserts together with sync)
```

### 8.3 IO Clock Gating

| Gating Point | Gate Condition | Wake-up Source |
|---|---|---|
| UART TX clock | No TX data pending | TX FIFO write |
| UART RX clock | Receiver disabled | RX enable register |
| SPI clock | SPI idle | SPI start command |
| DMA clock | All channels idle | DMA trigger |
| GPIO clock | Always on (interrupt source) | External pin |

---

## 9. SoC Integration Example

### 9.1 Complete MIPS SoC IO Subsystem

```
+------------------------------------------------------------------+
|                    MIPS interAptiv SoC                            |
|                                                                   |
| +-----------+ +-----------+                                       |
| | Core 0    | | Core 1    |  AXI Coherent Bus (ACE)              |
| | (L1 I/D)  | | (L1 I/D)  |=====================================|
| +-----+-----+ +-----+-----+                                     ||
|       |              |         +---------+      +-------------+  ||
|       +-----+--------+-------->| CM/GIC  |<---->| L2 Cache    |  ||
|                                  +----+----+      +-------------+  ||
|                                       |                            ||
|                                  +----v----+                       ||
|                                  | AXI Bus |========================+
|                                  | Fabric  |
|                                  +----+----+
|                                       |
|         +---------+---------+---------+---------+
|         |         |         |         |         |
|    +----v----+ +--v------+ +v-------+ +v------+ +v--------+
|    | DDR     | | AXI-to- | | SRAM   | | PCIe  | | DMA     |
|    | Ctrl    | | AHB     | | Ctrl   | | Ctrl  | | Engine  |
|    | (LPDDR4)| | Bridge  | | (TCM)  | | EP/RC | | (4 ch)  |
|    +---------+ +----+----+ +--------+ +-------+ +---------+
|                     |
|                +----v----+
|                | AHB Bus |
|                +----+----+
|                     |
|              +------+------+
|              |             |
|         +----v----+  +----v----+
|         | AHB-to- |  | Flash   |
|         | APB     |  | Ctrl    |
|         | Bridge  |  | (NOR)   |
|         +----+----+  +---------+
|              |
|         APB Bus
|    +--+--+--+--+--+--+--+--+
|    |  |  |  |  |  |  |  |  |
|   UART SPI I2C GPIO Timer WDT PWM Mailbox
```

### 9.2 Typical Register Map

| Base Address | Size | Peripheral | Bus |
|---|---|---|---|
| `0x0000_0000` | 256MB | DDR Memory | AXI |
| `0x1000_0000` | 64MB | NOR Flash | AHB |
| `0x1800_0000` | 8KB | SRAM (TCM) | AHB |
| `0x1800_2000` | 4KB | DMA Controller | AHB |
| `0x1800_3000` | 4KB | SPI Flash Controller | AHB |
| `0x1A00_0000` | 4KB | GIC | Internal |
| `0x1A00_1000` | 4KB | CM | Internal |
| `0x1B00_0000` | 4KB | PCIe Controller | AXI |
| `0x1C00_0000` | 256B | UART0 | APB |
| `0x1C00_0100` | 256B | UART1 | APB |
| `0x1C00_1000` | 256B | SPI0 | APB |
| `0x1C00_1100` | 256B | SPI1 | APB |
| `0x1C00_2000` | 256B | I2C0 | APB |
| `0x1C00_3000` | 1KB | GPIO0 (32 pins) | APB |
| `0x1C00_4000` | 256B | Timer0 | APB |
| `0x1C00_4100` | 256B | Timer1 | APB |
| `0x1C00_5000` | 256B | WDT | APB |
| `0x1C00_6000` | 256B | PWM | APB |
| `0x1C00_7000` | 256B | Mailbox (IPC) | APB |

---

## 10. Verification Considerations for IO Design

### 10.1 Bus Protocol Compliance

| Check | AHB | AXI4 | APB |
|---|---|---|---|
| VALID/READY handshake | HREADY | xVALID/xREADY | PREADY |
| Address alignment | HADDR vs HSIZE | AxADDR vs AxSIZE | PADDR |
| Burst boundary | 1KB boundary | 4KB boundary | N/A |
| Write strobe vs size | N/A (byte lane) | WSTRB vs AWSIZE | N/A |
| Response encoding | HRESP=OKAY/ERROR | xRESP=OKAY/SLVERR/DECERR | No response |
| Exclusive access | HMASTLOCK | AxLOCK | N/A |
| Outstanding limit | 1 per master | ID-based ordering | 1 |

### 10.2 DMA Verification Scenarios

| Scenario | Description | Key Checks |
|---|---|---|
| Basic mem-to-mem | Single channel, contiguous | Data integrity, size match |
| Scatter-gather | Linked descriptors | Chain traversal, boundary |
| Concurrent channels | Multiple channels active | Arbitration, no corruption |
| Abort mid-transfer | Software abort command | Clean state, no partial write |
| Error handling | Bus error during DMA | Error interrupt, status register |
| Coherent vs non-coherent | Different CCA settings | Cache state correctness |
| Wrap-around address | Source/dest crosses 4GB | Address overflow handling |

### 10.3 Interrupt Verification

| Scenario | Description |
|---|---|
| Level-triggered IRQ | Assert during ISR — re-enter if not cleared |
| Edge-triggered IRQ | Missed edge if arrives during disabled IE |
| Interrupt priority | Higher IRQ preempts lower ISR |
| Nested interrupts | EXL=0 inside ISR allows nesting |
| IPI (Inter-Processor) | Core-to-core interrupt via GIC |
| EIC vectored | Direct vector to correct ISR entry |

### 10.4 SVA Assertions for IO Bus

```systemverilog
// AHB: HREADY must be high before address changes
property p_ahb_addr_stable;
    @(posedge HCLK) disable iff (!HRESETn)
    (HTRANS != 2'b00 && !HREADY) |=> $stable(HADDR);
endproperty
assert_ahb_addr_stable: assert property (p_ahb_addr_stable);

// AXI: VALID must not depend on READY (no combinational loop)
property p_axi_valid_no_ready_dep;
    @(posedge ACLK) disable iff (!ARESETn)
    $rose(AWVALID) |-> !AWREADY [*0];  // Valid asserted independent of ready
endproperty

// APB: PENABLE must follow PSEL by one cycle
property p_apb_enable_follows_sel;
    @(posedge PCLK) disable iff (!PRESETn)
    $rose(PSEL) |=> PENABLE;
endproperty
assert_apb_enable: assert property (p_apb_enable_follows_sel);

// DMA: No transfer when channel disabled
property p_dma_no_xfer_when_disabled;
    @(posedge clk) disable iff (!rst_n)
    (!dma_ch_enable) |=> !dma_active;
endproperty
assert_dma_disabled: assert property (p_dma_no_xfer_when_disabled);
```

---

## 11. Design Checklist for MIPS IO Integration

| # | Check Item | Status |
|---|---|---|
| 1 | MMIO registers accessed via uncached segment (kseg1) | ☐ |
| 2 | DMA CCA correctly programmed for each channel | ☐ |
| 3 | Cache flush/invalidate before/after non-coherent DMA | ☐ |
| 4 | Bus bridges handle burst type conversion correctly | ☐ |
| 5 | AXI-to-AHB bridge preserves transaction ordering | ☐ |
| 6 | APB bridge waits for PREADY before completing transfer | ☐ |
| 7 | Interrupt polarity and edge/level configured correctly | ☐ |
| 8 | GIC interrupt routing matches system map | ☐ |
| 9 | Reset sequence: PLL→Core→Bus→IO (upstream first) | ☐ |
| 10 | Clock domains identified; CDC synchronizers in place | ☐ |
| 11 | DMA descriptor addresses are physical (not virtual) | ☐ |
| 12 | IO agent uses correct address width (32-bit or 64-bit) | ☐ |
| 13 | Write ordering enforced with `sync` after MMIO writes | ☐ |
| 14 | Exclusive access (LL/SC) supported on IO bus if needed | ☐ |
| 15 | Debug access port (EJTAG) can access IO register space | ☐ |
| 16 | Power gating plan for unused IO blocks | ☐ |
| 17 | All SVA assertions cover handshake, ordering, response | ☐ |
| 18 | DMA linked-list chain crosses page boundary correctly | ☐ |
| 19 | PCIe MSI-X interrupts routed through GIC correctly | ☐ |
| 20 | Bus error responses handled and logged | ☐ |

---

## Appendix: Glossary

| Term | Definition |
|---|---|
| **CM** | Coherence Manager — manages cache coherency for MIPS multi-core |
| **GIC** | Global Interrupt Controller — MIPS scalable interrupt controller |
| **IOCB** | IO Coherency Bus — interface for IO agents to participate in coherency |
| **CCA** | Cache Coherency Attribute — determines caching behavior of transactions |
| **TCM** | Tightly Coupled Memory — low-latency SRAM connected to core |
| **EJTAG** | MIPS debug interface (IEEE 1149.1 based) |
| **EIC** | External Interrupt Controller — external IC mode in MIPS |
| **VPE** | Virtual Processing Element — MIPS hardware thread |
| **TC** | Thread Context — MIPS hardware thread execution context |
| **LL/SC** | Load-Linked / Store-Conditional — MIPS atomic operation mechanism |
| **BEV** | Bootstrap Exception Vector — selects boot-time exception vectors |
| **BEV=0** | Normal: exception vectors in kseg0 (cached DRAM) |
| **BEV=1** | Bootstrap: exception vectors in kseg1 (uncached ROM) |
