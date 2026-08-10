## 5. 构建与测试

| 任务        | 命令                  |
|-------------|-----------------------|
| 类型检查    | `./scripts/typecheck.sh`  |
| 代码格式化  | `./scripts/format.sh`     |
| Lint        | `./scripts/lint.sh`       |
| 单元测试    | `./scripts/test.sh`       |
| 生产构建    | `./scripts/build.sh`      |

> 所有命令都通过 `scripts/*.sh` 包装；底层命令源自真实 manifest，不允许代理改动命令源。
