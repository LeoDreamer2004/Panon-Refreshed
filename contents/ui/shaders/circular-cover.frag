#version 440
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
};
layout(binding = 1) uniform sampler2D source;
void main() {
    float radius = length(qt_TexCoord0 - vec2(0.5));
    float feather = max(fwidth(radius), 0.001);
    float alpha = 1.0 - smoothstep(0.5 - feather, 0.5, radius);
    fragColor = texture(source, qt_TexCoord0) * alpha * qt_Opacity;
}
