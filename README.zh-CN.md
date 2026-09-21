# Panon-Refreshed

![Desktop](./contents/demo/desktop.png)
![Bar](./contents/demo/bar.png)

[English](README.md) | 简体中文

面向 KDE Plasma 的音频可视化组件，提供频谱、旋转专辑封面、同步歌词和标准 MPRIS 播放控制，并针对桌面与面板提供不同布局。

**仅支持 Plasma 6，不支持 Plasma 5。**

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

在“音乐软件集成”页自动检测播放器路径并更新独立的 `.desktop` 启动项，随后完全退出播放器（包括托盘后台），从带有“Panon 集成”的菜单入口重新启动；上游文件和原启动项保持不变。
移动项目或更改播放器路径后需再次更新启动项，通用频谱与 MPRIS 控制则无需启用这些桥接。

## 验证状态

目前实际验证过的桌面环境：Arch Linux、Plasma 6.7.5、Qt 6.11.2、Python 3.14、Wayland。元数据中的最低版本是加载声明，不代表所有 Plasma 6 小版本都经过测试。
