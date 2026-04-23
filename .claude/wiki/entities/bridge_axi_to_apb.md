# bridge_axi_to_apb

> AXI4-Lite 到 APB 协议桥接器，用于高速互联到低速外设的接口转换

## 基本信息

| 字段 | 值 |
|------|----|
| 类型 | CBB |
| 来源 | .claude/knowledge/cbb/bridge_axi_to_apb.md |

## 核心特性
- AXI4-Lite 从接口转 APB 主接口，支持完整 APB 时序（SETUP→ACCESS）
- AXI 写地址/写数据并行握手，简化协议转换
- APB PSLVERR 映射为 AXI DECERR 响应
- 支持多 APB 从设备选择，内置地址解码
- 写 3 cycle / 读 3 cycle 固定延迟（不含 AXI 握手等待）

## 关键参数

| 参数 | 默认值 | 范围 | 说明 |
|------|--------|------|------|
| `AXI_ADDR_WIDTH` | 32 | ≥16 | AXI 地址位宽 |
| `AXI_DATA_WIDTH` | 32 | 32/64 | AXI 数据位宽 |
| `APB_ADDR_WIDTH` | 16 | ≥8 | APB 地址位宽 |
| `APB_DATA_WIDTH` | 32 | 32 | APB 数据位宽 |
| `NUM_APB_SLAVES` | 4 | ≥1 | APB 从设备数量 |
| `PIPE_EN` | 0 | 0/1 | 输出流水线使能 |

## 接口信号

| 信号 | 方向 | 位宽 | 说明 |
|------|------|------|------|
| `s_axi_*` | I/O | AXI4-Lite 标准 | AXI 从接口（AW/W/B/AR/R 通道） |
| `apb_paddr` | O | APB_ADDR_WIDTH | APB 地址 |
| `apb_psel` | O | NUM_APB_SLAVES | APB 从设备选择 |
| `apb_penable` | O | 1 | APB 使能（ACCESS 阶段） |
| `apb_pwdata` | O | APB_DATA_WIDTH | APB 写数据 |
| `apb_prdata` | I | NUM_APB_SLAVES×APB_DATA_WIDTH | APB 读数据 |
| `apb_pready` | I | NUM_APB_SLAVES | APB 就绪 |
| `apb_pslverr` | I | NUM_APB_SLAVES | APB 从设备错误 |

## 典型应用场景
- SoC 外设配置总线：CPU 通过 AXI 访问 UART/SPI/I2C/GPIO/Timer
- 低速外设桥接：将高速域的配置请求转换为低速 APB 事务

## 与其他实体的关系
- 常与 address_decoder 配合完成 AXI 地址到 APB 从设备的映射
- 下游连接 axi4_lite_reg_file 等 APB 从设备

## 设计注意事项
- 无缓冲，每次只处理一个 AXI 事务，不支持 outstanding
- APB 状态机：IDLE → SETUP → ACCESS → IDLE
- wstrb 直接映射为 APB PSTRB
- 面积约 1-2K GE，适合低带宽配置通路

## 参考
- 原始文档：`.claude/knowledge/cbb/bridge_axi_to_apb.md`
