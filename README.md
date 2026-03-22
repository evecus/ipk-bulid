# OpenWrt LuCI App Builder

通过 GitHub Actions 手动触发，快速生成 luci-app-xx 的 IPK 安装包。

## 使用方法

1. Fork 或克隆本仓库到你的 GitHub 账号
2. 进入 Actions → Build LuCI App IPK → Run workflow
3. 填写参数，点击运行
4. 构建完成后自动创建 Release 并上传 IPK

## 参数说明

| 参数 | 必填 | 说明 | 示例 |
|---|---|---|---|
| `package_name` | ✅ | 包名，服务名自动从中提取（去掉 luci-app- 前缀） | `luci-app-sub-store` |
| `service_title` | ✅ | 显示在菜单和页面标题的名称 | `Sub-Store` |
| `version` | ✅ | 版本号 | `1.0-r1` |
| `description` | ✅ | 显示在标题下方的介绍 | `简单的订阅管理器` |
| `binary` | ✅ | 二进制文件完整路径 | `/usr/bin/sub-store` |
| `start_args` | ❌ | 启动参数，用 `$变量名` 引用变量，留空则直接启动 | `--port=$port --path=$backend_path` |
| `has_web` | ✅ | 是否有 Web 界面 | `true` / `false` |
| `web_entry` | ❌ | 网页入口，has_web=true 时填写 | `3001` 或 `3001/ui` |
| `extra_options` | ❌ | 补充输入框定义，格式见下方 | `port:3001:端口 backend_path:/sub-store:后端路径` |

## extra_options 格式

每个变量一组，空格分隔，格式为 `变量名:默认值:显示标签`：

```
port:3001:端口 backend_path:/sub-store:后端路径 data_dir:/etc/sub-store:数据保存路径
```

变量名需要和 `start_args` 里的 `$变量名` 对应。

## 示例：Sub-Store

```
package_name:  luci-app-sub-store
service_title: Sub-Store
version:       1.0-r1
description:   简单的订阅管理器
binary:        /usr/bin/sub-store
start_args:    --port=$port --path=$backend_path --dir=$data_dir
has_web:       true
web_entry:     3001
extra_options: port:3001:端口 backend_path:/sub-store:后端路径 data_dir:/etc/sub-store:数据保存路径
```

## 示例：Frpc（无 Web 界面，参数简单）

```
package_name:  luci-app-frpc
service_title: Frpc
version:       1.0-r1
description:   frp 内网穿透客户端
binary:        /usr/bin/frpc
start_args:    -c $config_file
has_web:       false
web_entry:     （留空）
extra_options: config_file:/etc/frpc/frpc.toml:配置文件路径
```

## 示例：只有二进制，无参数

```
package_name:  luci-app-myapp
service_title: MyApp
version:       1.0-r1
description:   我的应用
binary:        /usr/bin/myapp
start_args:    （留空）
has_web:       false
web_entry:     （留空）
extra_options: （留空）
```
