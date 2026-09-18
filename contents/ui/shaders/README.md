# Qt 6 shaders

The `.qsb` files are bundled so installing the widget does not require a shader
compiler. After editing the GLSL sources, rebuild using Qt 6 Shader Tools:

```sh
qsb --qt6 --qsbversion 64 -o lyric-fade.frag.qsb lyric-fade.frag
qsb --qt6 --qsbversion 64 -o circular-cover.frag.qsb circular-cover.frag
```

Both effects use one texture sample per pixel; neither performs blur.
The serialized format targets Qt 6.4 for compatibility with Plasma 6's Qt baseline.
Software rendering keeps circular covers via Canvas and disables the edge mask.
