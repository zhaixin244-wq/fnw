# cdc_sync

> 跨时钟域同步器集合，提供双触发器、脉冲同步、握手同步三种方案

## 基本信息

| 字段 | 值 |
|------|----|
| 类型 | CBB |
| 来源 | .claude/knowledge/cbb/cdc_sync.md |

## 核心特性
- 子模块 A：双触发器同步器（sync_2ff），单 bit 电平信号，延迟 2 cycles
- 子模块 B：脉冲同步器（sync_pulse），单周期脉冲，延迟 3 cycles
- 子模块 C：握手同步器（sync_handshake），多 bit 数据，延迟 ≥4 cycles
- 所有方案基于标准 2FF 同步器，亚稳态恢复概率可控

## 关键参数

| 参数 | 默认值 | 范围 | 说明 |
|------|--------|------|------|
| WIDTH (2FF) | 1 | ≥1 | 同步信号位宽 |
| STAGES (2FF) | 2 | 2-3 | 同步器级数 |
| DATA_WIDTH (HS) | 32 | ≥1 | 握手同步数据位宽 |
| STAGES (HS) | 2 | 2-3 | 握手同步器级数 |

## 接口信号

| 信号 | 方向 | 位宽 | 说明 |
|------|------|------|------|
| clk_src / clk_dst | I | 1 | 源/目标时钟域 |
| rst_src_n / rst_dst_n | I | 1 | 源/目标域异步复位 |
| data_src (2FF) | I | WIDTH | 源域信号（须为寄存器输出） |
| data_dst (2FF) | O | WIDTH | 同步后信号 |
| pulse_src/dst (PS) | I/O | 1 | 源/目标域脉冲 |
| data_src/dst (HS) | I/O | DATA_WIDTH | 握手同步数据 |
| valid_src/dst (HS) | I/O | 1 | 数据有效 |
| ready_src/dst (HS) | O/I | 1 | 握手完成/就绪 |

## 典型应用场景
- sync_2ff：enable/config 等单 bit 控制信号跨域
- sync_pulse：中断/start 等单周期脉冲跨域
- sync_handshake：配置寄存器、状态上报等多 bit 数据跨域

## 与其他实体的关系
- `cdc_handshake_bus` 是 sync_handshake 的独立封装版本
- `cdc_pulse_stretch` 是 sync_pulse 的增强版（展宽防丢失）
- `gray_converter` 配合异步 FIFO 使用，适用于高频多 bit 场景
- sync_handshake 吞吐较低时，高频场景应选用异步 FIFO

## 设计注意事项
- sync_2ff：data_src 必须是寄存器输出，禁止组合逻辑直接输入
- sync_pulse：两脉冲间隔须 ≥ 3 个 dst_clk 周期，否则丢失
- sync_handshake：data_src 须在 valid_src=1 期间保持稳定
- 方案选择：单 bit 电平→2FF，单 bit 脉冲→Pulse Sync，多 bit 低频→Handshake，多 bit 高频→异步 FIFO

## 参考
- 原始文档：`.claude/knowledge/cbb/cdc_sync.md`
