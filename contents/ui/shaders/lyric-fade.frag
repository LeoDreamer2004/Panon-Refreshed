#version 440
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float fadeSize;
};
layout(binding = 1) uniform sampler2D source;
void main() {
    float edge = min(qt_TexCoord0.y, 1.0 - qt_TexCoord0.y);
    float alpha = smoothstep(0.0, max(0.001, fadeSize), edge);
    fragColor = texture(source, qt_TexCoord0) * alpha * qt_Opacity;
}
