# RTL 设计模式库方法论

> 定义可复用的 RTL 设计模式、模式选择决策树和参数化模板，提升 RTL 实现的一致性和首次通过率。

---

## 1. 模式分类体系

### 1.1 模式层级

| 层级 | 说明 | 示例 |
|------|------|------|
| **L0 原子模式** | 单一功能的最小可复用单元 | 双触发器同步、握手寄存器、二进制计数器 |
| **L1 组合模式** | 多个原子模式组合完成子功能 | 异步 FIFO（Gray 码 + 双触发器 + 环形缓冲）、仲裁器（优先级编码 + 输出寄存） |
| **L2 架构模式** | 完整子模块级架构 | 流控引擎、寄存器文件 + APB 从接口、数据通路 + 控制通路分离 |

### 1.2 模式目录

| 模式 ID | 模式名称 | 层级 | 适用场景 | 编码规范章节 |
|---------|---------|------|----------|-------------|
| PAT-001 | 双触发器同步 | L0 | 单 bit CDC | §5, CDC 方法论 |
| PAT-002 | 脉冲同步器 | L0 | 跨域脉冲传递 | §5, CDC 方法论 |
| PAT-003 | 握手寄存器 | L0 | 跨域数据锁存 | §5, CDC 方法论 |
| PAT-004 | 二进制计数器 | L0 | 通用计数 | §7 |
| PAT-005 | 格雷码计数器 | L0 | CDC 安全计数 | §5, CDC 方法论 |
| PAT-006 | 优先级编码器 | L0 | 固定优先级选择 | §13 |
| PAT-007 | 轮询仲裁器 | L0 | 公平仲裁 | §13 |
| PAT-008 | 握手流水线寄存器 | L0 | 带反压的数据流水线 | §8 |
| PAT-009 | 异步 FIFO | L1 | 跨时钟域数据传输 | §9, CDC 方法论 |
| PAT-010 | 同步 FIFO | L1 | 同域数据缓冲 | §9 |
| PAT-011 | Credit 流控 | L1 | 端到端流控 | §13 |
| PAT-012 | 请求-应答桥 | L1 | 协议转换 | §13 |
| PAT-013 | 寄存器文件 + APB | L2 | 配置寄存器组 | §13 |
| PAT-014 | 数据通路 + 控制通路分离 | L2 | 复杂数据处理模块 | §12 |
| PAT-015 | 流控引擎 | L2 | 完整流控子系统 | §9 |
| PAT-016 | 链表管理器 | L2 | 动态资源分配 | §13 |

---

## 2. 模式选择决策树

### 2.1 数据缓冲模式选择

```
需要缓冲数据？
├─ 跨时钟域？
│  ├─ 是 → 数据位宽 > 1？
│  │  ├─ 是 → PAT-009 异步 FIFO
│  │  └─ 否 → PAT-001 双触发器同步（单 bit）/ PAT-002 脉冲同步器（脉冲）
│  └─ 否 → 需要反压？
│     ├─ 是 → PAT-010 同步 FIFO
│     └─ 否 → 直接寄存器传递（PAT-008 握手流水线寄存器）
└─ 不需要缓冲 → 组合逻辑直连
```

### 2.2 流控模式选择

```
需要流控？
├─ 端到端（跨多个模块）？
│  ├─ 是 → PAT-011 Credit 流控
│  └─ 否 → 点到点？
│     ├─ 握手协议足够 → Valid-Ready 握手（编码规范 §8）
│     └─ 需要突发缓冲 → PAT-010 同步 FIFO + 握手
```

### 2.3 仲裁模式选择

```
多源竞争？
├─ 有 QoS/优先级需求？
│  ├─ 是 → PAT-006 优先级编码器（固定优先级）
│  └─ 否 → 需要公平性？
│     ├─ 是 → PAT-007 轮询仲裁器（RR）
│     └─ 否 → 固定优先级即可
└─ 无竞争 → 无需仲裁
```

### 2.4 CDC 模式选择

```
跨时钟域信号？
├─ 单 bit 电平？
│  └─ PAT-001 双触发器同步
├─ 单 bit 脉冲？
│  └─ PAT-002 脉冲同步器
├─ 多 bit 数据？
│  ├─ 数据位宽 ≤ 8 且速率低 → PAT-003 握手寄存器
│  └─ 数据位宽 > 8 或高速率 → PAT-009 异步 FIFO
└─ 多 bit 计数器/指针？
   └─ PAT-005 格雷码计数器 + PAT-001 双触发器同步
```

---

## 3. 参数化模板

### 3.1 PAT-001: 双触发器同步器

```verilog
// Pattern: PAT-001 双触发器同步器
// 用途: 单 bit CDC 电平同步
// 参数: 无
// 依赖: 无
module sync_2ff #(
    parameter integer INIT_VAL = 0  // 复位值
)(
    input  wire clk_dst,    // 目标时钟域
    input  wire rst_n,      // 异步复位
    input  wire sig_src,    // 源时钟域信号
    output wire sig_dst     // 同步后信号
);
    reg sig_sync1_r, sig_sync2_r;

    always @(posedge clk_dst or negedge rst_n) begin
        if (!rst_n) begin
            sig_sync1_r <= INIT_VAL[0];
            sig_sync2_r <= INIT_VAL[0];
        end else begin
            sig_sync1_r <= sig_src;
            sig_sync2_r <= sig_sync1_r;
        end
    end

    assign sig_dst = sig_sync2_r;
endmodule
```

### 3.2 PAT-002: 脉冲同步器

```verilog
// Pattern: PAT-002 脉冲同步器（源域展宽 + 目标域边沿检测）
// 用途: 跨域脉冲传递
// 参数: 无
// 依赖: PAT-001
module pulse_sync (
    input  wire clk_src,
    input  wire clk_dst,
    input  wire rst_n,
    input  wire pulse_src,   // 源域单周期脉冲
    output wire pulse_dst    // 目标域单周期脉冲
);
    // 源域: 脉冲→电平翻转
    reg toggle_src;
    always @(posedge clk_src or negedge rst_n) begin
        if (!rst_n) toggle_src <= 1'b0;
        else if (pulse_src) toggle_src <= ~toggle_src;
    end

    // 目标域: 双触发器同步
    reg toggle_sync1, toggle_sync2, toggle_sync3;
    always @(posedge clk_dst or negedge rst_n) begin
        if (!rst_n) begin
            toggle_sync1 <= 1'b0;
            toggle_sync2 <= 1'b0;
            toggle_sync3 <= 1'b0;
        end else begin
            toggle_sync1 <= toggle_src;
            toggle_sync2 <= toggle_sync1;
            toggle_sync3 <= toggle_sync2;
        end
    end

    // 边沿检测
    assign pulse_dst = toggle_sync2 ^ toggle_sync3;
endmodule
```

### 3.3 PAT-007: 轮询仲裁器

```verilog
// Pattern: PAT-007 参数化轮询仲裁器
// 用途: N 路公平仲裁
// 参数: N = 仲裁路数
// 依赖: 无
module rr_arbiter #(
    parameter integer N = 4
)(
    input  wire       clk,
    input  wire       rst_n,
    input  wire [N-1:0] req_i,    // 仲裁请求
    output reg  [N-1:0] gnt_o     // 仲裁授权（独热码）
);
    localparam integer SEL_W = $clog2(N);

    reg [SEL_W-1:0] ptr_r;  // RR 指针

    wire [N-1:0] masked_req = req_i & ~({N{1'b1}} >> (N - 1 - ptr_r));
    wire [N-1:0] unmasked_req = req_i;

    integer i;
    reg [SEL_W-1:0] sel;

    always @(*) begin
        gnt_o = {N{1'b0}};
        sel = ptr_r;

        // 优先: masked（ptr 之后的请求）
        if (|masked_req) begin
            for (i = 0; i < N; i = i + 1) begin
                if (masked_req[i]) begin
                    sel = i[SEL_W-1:0];
                    gnt_o = {{(N-1){1'b0}}, 1'b1} << i;
                end
            end
        // 其次: unmasked（ptr 之前的请求）
        end else if (|unmasked_req) begin
            for (i = 0; i < N; i = i + 1) begin
                if (unmasked_req[i]) begin
                    sel = i[SEL_W-1:0];
                    gnt_o = {{(N-1){1'b0}}, 1'b1} << i;
                end
            end
        end
    end

    // RR 指针更新: 授权后移到下一位
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ptr_r <= {SEL_W{1'b0}};
        end else if (|gnt_o) begin
            ptr_r <= (sel == N-1) ? {SEL_W{1'b0}} : sel + 1'b1;
        end
    end
endmodule
```

### 3.4 PAT-011: Credit 流控

```verilog
// Pattern: PAT-011 Credit 流控
// 用途: 端到端流控，防止发送端超发
// 参数: CREDIT_MAX = 最大信用值, CREDIT_W = 信用计数器位宽
// 依赖: 无
module credit_flow_ctrl #(
    parameter integer CREDIT_MAX = 16,
    parameter integer CREDIT_W  = $clog2(CREDIT_MAX + 1)
)(
    input  wire clk,
    input  wire rst_n,
    // 发送端
    input  wire tx_valid,
    output wire tx_ready,       // 有 credit 时可发
    // 接收端
    input  wire rx_consume,     // 接收端消耗一个 credit
    // 信用管理
    input  wire credit_return,  // 远端返回 credit
    input  wire [CREDIT_W-1:0] credit_return_cnt
);
    reg [CREDIT_W-1:0] credit_r;

    assign tx_ready = (credit_r != {CREDIT_W{1'b0}});

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            credit_r <= CREDIT_MAX[CREDIT_W-1:0];
        end else begin
            // 优先: 消耗（发送时扣减）; 回收（远端返回时增加）
            case ({tx_valid && tx_ready, credit_return})
                2'b10:   credit_r <= credit_r - 1'b1;
                2'b01:   credit_r <= credit_r + credit_return_cnt;
                2'b11:   credit_r <= credit_r - 1'b1 + credit_return_cnt;
                default: ;  // 无变化
            endcase
        end
    end
endmodule
```

---

## 4. 模式使用规范

### 4.1 模式引用规则

| 规则 | 说明 |
|------|------|
| **优先复用** | 编码前先查模式库，匹配度 ≥ 70% 的模式必须复用 |
| **参数化适配** | 通过 `parameter` 适配具体需求，禁止硬编码修改模式代码 |
| **注释标注** | 使用模式时标注 `// Pattern: PAT-XXX` |
| **组合记录** | 使用 L1/L2 模式时，在文档中记录包含的 L0 子模式 |

### 4.2 模式扩展规则

| 场景 | 处理方式 |
|------|----------|
| 模式匹配度 50~70% | 参考模式结构，标注 `[PATTERN-VARIANT]` |
| 模式匹配度 < 50% | 自研设计，完成后评估是否纳入模式库 |
| 发现新模式 | 提交模式描述，经 chip-arch-reviewer 评审后纳入 |

### 4.3 模式质量标准

| 标准 | 要求 |
|------|------|
| **可综合性** | 模式代码必须通过 Verible + Verilator lint |
| **参数化** | 所有可变维度必须用 `parameter` 定义 |
| **自包含** | 模式模块无外部隐式依赖 |
| **文档完备** | 每个模式有用途说明、参数表、使用示例 |
| **CDC 安全** | 跨域模式必须标注 CDC 策略 |

---

## 5. 集成规则

### 5.1 chip-code-writer 集成

- 编码前必须查询模式库（PAT-001~016）
- 匹配度 ≥ 70% 的模式直接实例化，标注 `// Pattern: PAT-XXX`
- 匹配度 50~70% 的模式参考结构，标注 `[PATTERN-VARIANT]`
- 模式代码作为独立文件或可识别代码块

### 5.2 chip-microarch-writer 集成

- §5 微架构设计阶段，识别可复用的模式
- §5.6 IP/CBB 集成中，CBB 模式优先于自研
- 模式选择决策树作为设计依据记录在文档中
