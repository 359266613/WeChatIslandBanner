## WeChat Island Banner

**功能**：在微信内收到新消息时，在灵动岛区域显示一条自定义横幅通知（只在微信内弹，不依赖系统通知中心）。

### 环境

- iOS 16（已在 Dopamine 环境设计）
- Theos + Logos
- 微信 8.0.64（本仓库自带该版本的 `WeChat/*.h` 头文件）

### 编译

```bash
export THEOS=/opt/theos  # 按你的实际路径
make package
```

生成的 deb 在 `./packages/` 目录下。

### 部署

- 将 deb 传到设备（Filza / ssh / AirDrop 等），使用 Sileo / Zebra / `dpkg -i` 安装。
- 安装后会自动 `sbreload`，重新打开微信即可。

### 主要文件说明

- `Tweak.xm`  
  Hook `CMessageMgr` 的消息到达入口，从 `CMessageWrap` 解析发送者与内容，并调用横幅管理器。

- `WXBannerManager.h/m`  
  负责在状态栏之上绘制圆角横幅视图，淡入/停留/淡出，可点击关闭。

- `CydiaSubstrate/ellekit.m`  
  注册从 `CydiaSubstrate/*.h` dump 出来的占位类，避免运行时找不到类导致崩溃。

- `Makefile` / `control` / `WeChatIslandBanner.plist`  
  标准 Theos tweak 工程配置，支持直接 `make package` 生成 deb。


