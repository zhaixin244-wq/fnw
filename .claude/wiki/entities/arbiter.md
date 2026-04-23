# arbiter

> 多请求者共享单一资源时的仲裁器 CBB，支持固定优先级和轮询两种策略

## 基本信息

| 字段 | 值 |
|------|----|
| 类型 | CBB |
| 来源 | .claude/knowledge/cbb/arbiter.md |

## 核心特性
- 支持 Fixed Priority（固定优先级）和 Round Robin（轮询）两种仲裁策略
- 独热码 grant 输出 + 二进制 grant_idx，接口简洁
- 可选锁定机制：突发传输期间锁定仲裁，防止中途切换 master
- 无请求时 grant_valid=0，grant_idx 保持上次值
- NUM_REQ 参数化，适用任意端口数

## 关键参数

| 参数 | 默认值 | 范围 | 说明 |
|------|--------|------|------|
| `NUM_REQ` | 4 | ≥2 | 请求者数量 |
| `ARB_TYPE` | `"RR"` | `"FP"` / `"RR"` | 仲裁策略 |
| `LOCK_EN` | 0 | 0/1 | 锁定使能 |

## 接口信号

| 信号 | 方向 | 位宽 | 说明 |
|------|------|------|------|
| `clk` | I | 1 | 主时钟 |
| `rst_n` | I | 1 | 低有效异步复位 |
| `req` | I | `NUM_REQ` | 请求向量 |
| `grant` | O | `NUM_REQ` | 授权向量（独热码） |
| `grant_idx` | O | `$clog2(NUM_REQ)` | 授权索引 |
| `grant_valid` | O | 1 | 存在有效授权 |
| `lock` | I | 1 | 锁定当前 grant（`LOCK_EN=1` 时有效） |
| `release` | I | 1 | 释放锁定（`LOCK_EN=1` 时有效） |

## 典型应用场景
- DMA 通道竞争存储端口：FP 策略保证高优先级通道优先
- 多 master 共享 AXI 总线：RR 策略保证公平访问
- 突发传输仲裁：`LOCK_EN=1`，burst_start 锁定，burst_last_beat 释放

## 与其他实体的关系
- 固定优先级模式内部使用 **priority_encoder** 实现
- 轮询模式使用 mask 屏蔽已服务低位，支持轮转公平性
- 大位宽（N≥128）场景应使用 **bigrr** 替代

## 设计注意事项
- 固定优先级：`req & (~req + 1)` 提取最低有效位
- 轮询：`req & mask` 找下一个，mask 耗尽后重置
- 锁定机制：lock=1 冻结 pointer，release=1 更新 pointer 到 grant_idx+1
- grant_valid=0 时下游不应消费数据

## 参考
- 原始文档：`.claude/knowledge/cbb/arbiter.md`
