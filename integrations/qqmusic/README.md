# QQ 音乐专用集成

支持 Arch `qqmusic-electron 1.1.8-5`，使用 `/usr/lib/qqmusic/app.asar` 和系统 Electron 43。
不是旧的 `/opt/qqmusic` 内置 Electron 8 版本，也不是通用 QQ 音乐网页适配器。

## 启动

安装器支持 `--app-path /absolute/path/app.asar`、`--electron /path/to/electron` 和 `--dry-run`。配置保存至 `$XDG_CONFIG_HOME/panon/integrations/qqmusic.json`，优先于已知布局检测。
已验证版本映射在 `adapters.json`：QQ Music 1.1.8、Electron 43。未知版本或运行时仍拒绝接入，显式路径不等于支持未知构建；不会遍历执行任意 Webpack 模块。
移动项目后重新运行安装器；更新启动入口代码后需完全退出并重新启动播放器。Flatpak/AppImage 尚未适配。

先完全退出原 QQ 音乐，再运行：

```sh
electron43 '/absolute/path/to/panon-refreshed/integrations/qqmusic/launch.cjs'
```

如果确实需要关闭沙箱，显式添加 `--no-sandbox`；桥接本身不要求关闭沙箱。
在项目根目录运行 `python3 integrations/qqmusic/install-launcher.py` 添加“QQ音乐（Panon 集成）”菜单入口。
安装器可传 `--no-sandbox` 保存该选择。原启动器、系统安装、用户登录配置和自启动设置不变。
从旧入口启动不会提供桥接，也不会启用标题搜索兜底。

## 机制

- 入口加载原包，只对包内 `index.html` 执行适配脚本，不接触登录窗口或远程 webview。
- 通过已加载的 Webpack 模块取得播放器单例 `Player.currentSong`，校验歌曲 ID、歌名、首位歌手和专辑与 Media Session 同步。
- 数字歌曲 ID 和 MID 来自当前播放器，不是搜索、播放列表或浏览地址。
- 使用软件自身 `ufetch` 的 `music.pf_song_detail_svr/get_song_detail` 获取精确 ID 对应的歌词。
- 原请求内部正常使用播放器的登录状态，但不将 Cookie、令牌等导出给 Panon；本地 JSON 仅包含白名单曲目信息和歌词。
- 页面内每首歌缓存结果，失败最多重试三次、间隔至少 15 秒；异步结果按 ID 隔离，切歌不会串歌词。
- 每 750 ms 写 `$XDG_RUNTIME_DIR/panon/qqmusic-<PID>.json`（0600，原子替换）。Panon 核对提供者、D-Bus 服务 PID、曲目信息与 5 秒时效。
- 翻译使用同一歌曲 ID/MID 的 `music.musichallSong.PlayLyricInfo/GetPlayLyricInfo`（`crypt:0, qrc:0, roma:0, trans:1`），将 Base64 UTF-8 翻译解码为同步 LRC。独立请求、有限重试；没有翻译或请求失败时保留原文，迟到的翻译自动刷新，可用“译”按钮开关。
- 日语可用本地注音，尚未接入 QQ 平台读音；不借用网易云的其他录音版本。

保留封面、播放进度、切歌、暂停、歌词点击跳转等通用 MPRIS 功能。
内部模块不是稳定 API；版本或模块结构不匹配时不输出 ID，需更新适配器。

## 验证

```sh
node tests/test_qqmusic_page.cjs
python3 tests/test_netease_bridge.py
```
