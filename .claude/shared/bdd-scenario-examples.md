# BDD 行为场景示例

> 基于 data_adpt（数据适配器）项目的实际需求，展示 BDD 场景编写方法。
> 供 chip-verfi-arch 参考，非直接引用。

---

## 示例 1：数据传输场景（REQ-001 类型）

### 场景：REQ-001_normal_single_beat_transfer

**描述**：验证数据适配器在正常配置下完成单拍数据传输

**Given**：
- 寄存器配置：CTRL.EN = 1（模块使能）
- 接口信号：src_valid = 0，dst_ready = 1
- 时钟/复位：clk 200MHz 正常运行，rst_n 已释放
- 状态机：处于 S_IDLE 状态

**When**：
- 第 1 拍：src_valid 拉高，src_data = 32'hA5A5_A5A5，src_sop = 1，src_eop = 1

**Then**：
- 第 2~3 拍：状态机从 S_IDLE 转移到 S_DATA
- 第 3~4 拍：dst_valid 拉高，dst_data = 32'hA5A5_A5A5
- 第 4~5 拍：src_ready 拉高（握手完成）
- 无错误中断产生

**验证方法**：UVM Sequence（src_driver 发送单拍） + Scoreboard（数据比对）
**优先级**：P0
**覆盖 REQ**：REQ-001

---

### 场景：REQ-001_boundary_max_burst_length

**描述**：验证最大突发长度（16 拍）数据传输

**Given**：
- 寄存器配置：CTRL.EN = 1，CTRL.MAX_BURST = 16
- 接口信号：src_valid = 0，dst_ready = 1
- 时钟/复位：正常
- 状态机：S_IDLE

**When**：
- 第 1~16 拍：连续发送 16 拍数据，src_data 递增（0x0000_0001 ~ 0x0000_0010）
- 第 1 拍：src_sop = 1
- 第 16 拍：src_eop = 1

**Then**：
- 状态机经历 S_IDLE → S_DATA → S_DATA（保持 14 拍）→ S_IDLE
- dst_valid 连续拉高 16 拍，dst_data 与 src_data 一致
- 无数据丢失，无错误中断

**验证方法**：UVM Sequence（约束随机 burst_length=16） + Scoreboard
**优先级**：P1
**覆盖 REQ**：REQ-001

---

### 场景：REQ-001_error_src_timeout

**描述**：验证源端超时未发送数据时的异常处理

**Given**：
- 寄存器配置：CTRL.EN = 1，CTRL.TIMEOUT = 256（cycles）
- 接口信号：src_valid = 0，dst_ready = 1
- 时钟/复位：正常
- 状态机：S_IDLE

**When**：
- 第 1 拍：模块使能后，src_valid 保持为 0 持续 256 个时钟周期

**Then**：
- 第 257 拍：INT_STATUS.TIMEOUT 位被置 1
- 状态机回到 S_IDLE（或进入 S_ERROR，取决于设计）
- 无数据输出（dst_valid 保持 0）

**验证方法**：UVM Sequence（延迟注入） + SVA（超时检测）
**优先级**：P1
**覆盖 REQ**：REQ-001

---

## 示例 2：寄存器访问场景（REQ-002 类型）

### 场景：REQ-002_normal_apb_write_read

**描述**：验证 APB 接口正常写后读寄存器

**Given**：
- 接口信号：PSEL = 0，PENABLE = 0，PWRITE = 0
- 时钟/复位：正常
- 寄存器初始值：CTRL = 0x0000_0000

**When**：
- 第 1~3 拍（APB 写）：PSEL=1, PWRITE=1, PADDR=0x00, PWDATA=0x0000_0001
- 第 4~6 拍（APB 读）：PSEL=1, PWRITE=0, PADDR=0x00

**Then**：
- 写操作：CTRL 寄存器在第 3 拍后更新为 0x0000_0001
- 读操作：PRDATA 在第 6 拍返回 0x0000_0001
- PREADY 在正常延迟内拉高

**验证方法**：UVM Sequence（APB master driver） + SVA（寄存器值检查）
**优先级**：P0
**覆盖 REQ**：REQ-002

---

### 场景：REQ-002_boundary_reserved_field_write

**描述**：验证写保留位域的行为（应忽略写入）

**Given**：
- 寄存器初始值：CTRL = 0x0000_0000（[31:8] 为保留位）

**When**：
- APB 写：PADDR=0x00, PWDATA=0xFFFF_FF01

**Then**：
- CTRL 寄存器 = 0x0000_0001（保留位保持为 0，仅 [7:0] 被写入）

**验证方法**：SVA（保留位值检查）
**优先级**：P1
**覆盖 REQ**：REQ-002

---

## 示例 3：复位场景（REQ-003 类型）

### 场景：REQ-003_reset_async_assert_sync_release

**描述**：验证异步复位生效和同步释放

**Given**：
- 寄存器配置：CTRL = 0x0000_0001（已使能）
- 状态机：S_DATA（正在传输数据）
- 接口信号：src_valid = 1，src_data = 0xDEAD_BEEF

**When**：
- 第 1 拍（异步）：rst_n 拉低（复位生效）

**Then**：
- 立即（异步）：所有寄存器回到复位值（CTRL = 0x0000_0000）
- 立即（异步）：状态机回到 S_IDLE
- 立即（异步）：所有输出信号回到复位值（dst_valid = 0）

**验证方法**：UVM Sequence（异步复位注入） + SVA（复位值检查）
**优先级**：P1
**覆盖 REQ**：REQ-003

---

## 示例 4：功耗场景（REQ-007 类型）

### 场景：REQ-007_power_clock_gating

**描述**：验证时钟门控功能

**Given**：
- 寄存器配置：CTRL.EN = 1，CTRL.CGE = 1（时钟门控使能）
- 状态机：S_IDLE（空闲状态）

**When**：
- 第 1~10 拍：无数据传输请求（src_valid = 0）
- 第 11 拍：ICG 使能信号自动拉低

**Then**：
- 第 11 拍起：gated_clk 停止翻转
- 寄存器值保持不变
- 状态机保持 S_IDLE

**验证方法**：UVM Sequence（功耗控制） + SVA（时钟门控检查）
**优先级**：P2
**覆盖 REQ**：REQ-007

---

## 场景编写 Checklist

编写每个场景时，检查以下项：

- [ ] 场景 ID 命名符合 `{REQ}_{类型}_{简述}` 规则
- [ ] Given 条件具体化（寄存器值、信号值、状态名）
- [ ] When 动作单一触发（多触发拆分）
- [ ] Then 预期可量化（周期数、信号值）
- [ ] 验证方法明确（UVM/SVA/波形）
- [ ] 优先级标注（P0-P3）
- [ ] 覆盖 REQ 引用正确
