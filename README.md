## WeChat Island Banner (Island Only)

这个项目现在是**纯灵动岛通知版**，只保留微信内消息上岛能力，不包含任何“消息合并”功能。

### 功能

- 微信前台收到新消息时，在灵动岛区域显示横幅通知
- 支持头像、昵称、内容展示
- 支持点击横幅跳转会话
- 支持设置项（开关、宽高、背景/边框/文字颜色）
- 仅在微信内展示，不依赖系统通知中心

### 已移除功能

- 消息合并 Hook
- 消息合并设置页
- 消息合并配置模型

### 环境

- iOS 16+
- Theos + Logos
- 微信 8.0.64（按当前头文件适配）

### 编译

```bash
export THEOS=/opt/theos
make package
```

构建产物位于 `packages/`。

### 部署

- 把 deb 传到设备后使用 Sileo / Zebra / `dpkg -i` 安装
- 安装完成后重启微信验证

### 关键文件

- `Tweak.xm`：消息入口 Hook、文本过滤、会话抑制、去重
- `Sources/WXBannerManager.m`：横幅队列、渲染、动画、点击跳转
- `Controllers/WeChatIslandBannerSettingsController.m`：设置页 UI
- `Controllers/WIBConfig.m`：灵动岛配置持久化
- `Headers/WXWeChatStubs.h`：最小化微信类声明


