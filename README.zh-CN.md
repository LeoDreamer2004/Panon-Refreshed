# Panon-Refreshed

[English](README.md) | 简体中文

面向 KDE Plasma 的音频可视化组件，提供频谱、旋转专辑封面、同步歌词和标准 MPRIS 播放控制，并针对桌面与面板提供不同布局。

**仅支持 Plasma 6，不支持 Plasma 5。** 兼容性工作面向不同的 Plasma 6 环境，不包含向 Plasma 5 移植。

项目目录名为 `panon-refreshed`；代码包名、插件 ID 和现有组件名称仍保留 `panon` / `Panon`，安装命令和配置路径无需因此改名。

## 安装与依赖

需要 Linux、Plasma 6，以及以下 QML 模块：Qt Quick、Controls、Layouts、Kirigami、KCMUtils、Plasma5Support 和 Qt WebSockets。

Python 要求为 3.10 及以上，必需依赖见 [requirements.txt](requirements.txt)，可选的日语注音依赖见 [requirements-readings.txt](requirements-readings.txt)。优先使用发行版软件包，也可以在虚拟环境中安装依赖，然后在组件设置中选择该环境的解释器。编译安装 `dbus-python` 时可能需要 D-Bus 和 GLib 开发包。Panon-Refreshed 不要求使用 Intel MKL。

音频采集需要 `pactl`、`parec`，以及 PulseAudio 或 PipeWire 的 PulseAudio 兼容服务。音频采集失败不会禁用媒体信息和播放控制。

Qt5Compat GraphicalEffects 为可选依赖：缺失时不显示壁纸模糊效果，专辑封面改用 Canvas 实现圆形裁剪。

在项目根目录运行：

```sh
# 首次安装
kpackagetool6 --type Plasma/Applet --install .

# 更新已有安装
kpackagetool6 --type Plasma/Applet --upgrade .
```

更新后重新加载组件。可在配置页点击“检查依赖”，也可以进入 `contents/scripts` 后运行：

```sh
python3 -m panon.backend.doctor
```

## 可选的歌词集成

- [网易云网页播放器集成](integrations/netease/README.md)
- [QQ 音乐系统 Electron 版本集成](integrations/qqmusic/README.md)

通用频谱与 MPRIS 控制不依赖特定歌词提供方。歌词读取要求经过验证的当前歌曲 ID，不使用歌名搜索，也不会拿其他平台的录音版本替代。

两个集成启动项安装器都接受以下参数：

- `--app-path /absolute/path/app.asar`：播放器应用包。
- `--electron /path/to/electron`：播放器所支持的 Electron 运行时。
- `--dry-run`：只预览，不写入配置或菜单入口。

未明确指定时，仅检查已知安装布局；不能唯一确定时会报错。选择保存在 `$XDG_CONFIG_HOME/panon/integrations/<provider>.json` 中，生成的菜单入口记录所选可执行文件。自定义路径不代表兼容未知播放器构建或运行时；QQ 音乐已验证的版本与模块映射见 [adapters.json](integrations/qqmusic/adapters.json)。

集成不会修改上游播放器文件或原启动项。若移动项目目录，需重新运行相应启动项安装器。更新桥接启动代码后，应完全退出播放器（包括托盘后台），再从带有“Panon 集成”的菜单入口启动。原入口不会启用歌词桥接。

## 验证状态

目前实际验证过的桌面环境：Arch Linux、Plasma 6.7.5、Qt 6.11.2、Python 3.14、Wayland。元数据中的最低版本是加载声明，不代表所有 Plasma 6 小版本都经过测试。
