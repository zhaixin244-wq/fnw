# gray_converter

> 二进制码与 Gray 码互转，用于异步 FIFO 指针跨时钟域同步

## 基本信息

| 字段 | 值 |
|------|----|
| 类型 | CBB |
| 来源 | .claude/knowledge/cbb/gray_converter.md |

## 核心特性
- 纯组合逻辑，无寄存器、无流水线延迟
- 二进制→Gray：`gray = bin ^ (bin >> 1)`
- Gray→二进制：逐位异或还原，最高位直通
- 面积极小：N-1 个 XOR 门（单方向）

## 关键参数

| 参数 | 默认值 | 范围 | 说明 |
|------|--------|------|------|
| DATA_WIDTH | 4 | ≥2 | 数据位宽 |

## 接口信号

| 信号 | 方向 | 位宽 | 说明 |
|------|------|------|------|
| bin_in | I | DATA_WIDTH | 二进制输入 |
| gray_out | O | DATA_WIDTH | Gray 码输出（组合） |
| gray_in | I | DATA_WIDTH | Gray 码输入 |
| bin_out | O | DATA_WIDTH | 二进制输出（组合） |

## 典型应用场景
- 异步 FIFO 写指针：bin→Gray→2FF 同步到读域→Gray→bin
- 异步 FIFO 读指针：同上反向
- 任何需要 Gray 码编码的跨域指针传递

## 与其他实体的关系
- 是异步 FIFO 的必备组件，配合 `cdc_sync`（2FF 同步器）使用
- 与 `cdc_handshake_bus`、`cdc_pulse_stretch` 无直接关系
- Gray 码确保同步过程中不会采到非法中间值（相邻值仅 1 bit 变化）

## 设计注意事项
- 纯组合逻辑，嵌入指针寄存器路径中使用
- 不检测非法 Gray 码输入，需上层保证输入合法
- 异步 FIFO 指针位宽 = 地址位宽 + 1（满/空判断用）
- 面积：bin→gray N-1 XOR，gray→bin N-1 XOR

## 参考
- 原始文档：`.claude/knowledge/cbb/gray_converter.md`
