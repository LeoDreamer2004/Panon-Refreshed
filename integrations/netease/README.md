# 网易云专用路由（可选）

此目录由 Panon 维护，不修改系统播放器，不复制上游源码，不开启调试端口。
适配目标为 `netease-cloud-music-web-player` 的 `/st/webplayer` 页面；不是任意浏览器或所有网易云客户端的通用适配器。

## 使用

安装器支持 `--app-path /absolute/path/app.asar`、`--electron /path/to/electron` 和 `--dry-run`。显式配置优先，省略时只检查已知安装位置；找不到或存在多个候选时不猜测。
配置保存至 `$XDG_CONFIG_HOME/panon/integrations/netease.json`。移动项目后重新运行安装器；更新启动入口代码后完全退出并重新启动播放器。自定义路径并不代表支持所有播放器构建，Flatpak/AppImage 尚未适配。

先完全退出原播放器（只关窗口通常会留在托盘），再运行：

```sh
electron '/absolute/path/to/panon-refreshed/integrations/netease/launch.cjs'
```

可加 `--minimize`。保留原用户目录、登录状态和配置。需要系统已安装播放器和 Electron。
运行 `python3 integrations/netease/install-launcher.py` 可添加独立的应用菜单项“网易云音乐（Panon 集成）”。
它不替换原启动器或自动启动配置；以后应从新入口启动。卸载这个菜单项即可撤销启动集成。

## 数据与边界

- 启动入口加载系统原有 `app.asar`，通过 Electron `executeJavaScript` 只读检查网页。
- 只读取播放栏 `#page_pc_mini_bar` / `#btn_pc_minibar_play` 的已提交 React 数据。
- 要求 `curPlaying.track.id`、`trackId`、`onlineResourceId` 一致，且歌名、歌手、专辑与 Media Session 一致；本地文件、播客或结构变化时返回空 ID。
- 不扫描推荐列表、歌单或浏览地址，不读取 Cookie、认证信息和本地存储。
- 每 750 ms 原子写入 `$XDG_RUNTIME_DIR/panon/netease-<PID>.json`（0600）；退出清理，崩溃残留在 5 秒后失效。
- Panon 从 D-Bus 查询 MPRIS 服务拥有者 PID，核对来源身份、文件权限、时间和曲目信息后才接受 ID。
- 网易云路由只按确切 ID 获取原文/翻译/读音；缓存按平台和 ID 分开，不再搜索或替换为别的版本。目标版本缺少翻译时不会借用另一版本。
- 没有可信 ID 时保留媒体展示/控制，显示“暂无同步歌词”；仅平台明确标记无歌词时显示纯音乐提示。

网页内部结构并非稳定 API。`now-playing.js` 每次采样重新加载，可独立更新适配器，无需修改系统文件。
网站更新后可能需要维护；适配失败宁可没有歌词，也不自动按标题猜测。

## 测试

```sh
node tests/test_netease_page.cjs
python3 tests/test_netease_bridge.py
```
