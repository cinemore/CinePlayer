#include <metal_stdlib>
using namespace metal;

// 缩小后的光流位置和位移必须同时转换：纹理线性采样，像素向量按宽高比例放大。
kernel void metalFXExpandMotion(
    texture2d<float, access::sample> source [[texture(0)]],
    texture2d<float, access::write> destination [[texture(1)]],
    uint2 gid [[thread_position_in_grid]])
{
    if (gid.x >= destination.get_width() || gid.y >= destination.get_height()) return;
    constexpr sampler sample(coord::normalized, address::clamp_to_edge, filter::linear);
    float2 size = float2(destination.get_width(), destination.get_height());
    float2 vector = source.sample(sample, (float2(gid) + 0.5) / size).xy;
    vector *= size / float2(source.get_width(), source.get_height());
    destination.write(float4(vector, 0, 0), gid);
}
