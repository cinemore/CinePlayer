//
//  OpticalFlowBlendKernels.metal
//  Cinemore
//
//  光流补帧：用 Vision 光流对前后两帧做 warp+blend，输出中间帧。t=0.5 为正中插值。
//

#include <metal_stdlib>
using namespace metal;

constexpr sampler linearSampler(coord::normalized, address::clamp_to_edge, filter::linear);

/// 输入：第一帧、第二帧、光流图（RG32Float，像素位移）；常数 t ∈ [0,1]。输出：插值帧 BGRA。
kernel void opticalFlowBlend(
    texture2d<float, access::sample> firstTexture [[texture(0)]],
    texture2d<float, access::sample> secondTexture [[texture(1)]],
    texture2d<float, access::sample> flowTexture [[texture(2)]],
    texture2d<float, access::write> outputTexture [[texture(3)]],
    constant float &t [[buffer(0)]],
    uint2 gid [[thread_position_in_grid]])
{
    if (gid.x >= outputTexture.get_width() || gid.y >= outputTexture.get_height()) {
        return;
    }
    float w = float(outputTexture.get_width());
    float h = float(outputTexture.get_height());
    float2 uv = (float2(gid) + 0.5) / float2(w, h);

    // 光流为像素位移：先在像素空间计算模长，根据位移大小决定 warp 置信度，再转换到 [0,1] 纹理坐标偏移
    float2 flowPixels = flowTexture.sample(linearSampler, uv).xy;

    // 位移模长（像素）
    float len = length(flowPixels);

    // 位移过小：光流基本不动，直接认为可信；位移过大：可能遮挡/估计错误，认为不可信
    // 经验阈值，可后续按内容/性能再调优
    constexpr float L_low = 0.3;   // 像素，几乎静止
    constexpr float L_high = 6.0;  // 像素，位移较大，容易出错

    // 根据位移模长插值一个 [0,1] 置信度：1 表示完全使用 warp，0 表示退化为不 warp 的时间混合
    float c = 0.0;
    if (len <= L_low) {
        c = 1.0;
    } else if (len >= L_high) {
        c = 0.0;
    } else {
        // 线性插值：len 越接近 L_high，置信度越低
        c = 1.0 - ((len - L_low) / (L_high - L_low));
    }

    // 将像素位移转换到纹理坐标偏移，并按置信度缩放 warp 距离
    float2 flowNorm = flowPixels / float2(w, h);
    float2 flow1 = flowNorm * (t * c);
    float2 flow2 = -flowNorm * ((1.0 - t) * c);

    // warp 后的颜色（光流可信时主要依赖这一支）
    float4 col1Warp = firstTexture.sample(linearSampler, uv - flow1);
    float4 col2Warp = secondTexture.sample(linearSampler, uv - flow2);
    float4 colorWarped = (1.0 - t) * col1Warp + t * col2Warp;

    // 不 warp 的时间混合：光流不可信时退化到这里，牺牲一些运动锐度换更干净的画面
    float4 col1NoWarp = firstTexture.sample(linearSampler, uv);
    float4 col2NoWarp = secondTexture.sample(linearSampler, uv);
    float4 colorNoWarp = (1.0 - t) * col1NoWarp + t * col2NoWarp;

    // 最终输出：按置信度在 “warp 插帧” 与 “不 warp 的时间混合” 之间插值
    float4 finalColor = mix(colorNoWarp, colorWarped, c);
    outputTexture.write(finalColor, gid);
}
