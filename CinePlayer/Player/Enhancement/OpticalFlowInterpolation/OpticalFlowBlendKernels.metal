//
//  OpticalFlowBlendKernels.metal
//  Cinemore
//
//  双向光流补帧：prev/next 各自用对应方向的光流做 backward-warp 到中间时刻，
//  compose 阶段用颜色一致性 + 前后向一致性双重置信度，不可信区域 fallback 到
//  时间上更近的一帧，避免大位移/遮挡导致的鬼影。
//

#include <metal_stdlib>
using namespace metal;

constexpr sampler linearSampler(coord::normalized, address::clamp_to_edge, filter::linear);

/// 单向 backward-warp：对输出位置 p，从 input 的 `p - flow * scale` 采样。
/// prev 使用 forward flow + scale = t；next 使用 backward flow + scale = (1 - t)。
///
/// Snap-to-zero：位移 < 0.5 像素时直接归零，消除静态纹理区因 Vision 光流
/// 亚像素级随机噪声导致的"果冻感"——static 像素本不应 warp，但 Vision 逐帧
/// 输出轻微不同的噪声方向，累积起来就是肉眼可见的抖动。
kernel void opticalFlowWarp(
    texture2d<float, access::sample> inputTexture [[texture(0)]],
    texture2d<float, access::sample> flowTexture  [[texture(1)]],
    texture2d<float, access::write>  outputTexture [[texture(2)]],
    constant float &scale [[buffer(0)]],
    uint2 gid [[thread_position_in_grid]])
{
    if (gid.x >= outputTexture.get_width() || gid.y >= outputTexture.get_height()) {
        return;
    }
    float2 size = float2(outputTexture.get_width(), outputTexture.get_height());
    float2 uv = (float2(gid) + 0.5) / size;

    float2 flowPixels = flowTexture.sample(linearSampler, uv).xy;
    float flowMag = length(flowPixels);
    // 软门：<0.1 像素视为噪声完全归零；>0.25 像素视为真实运动完全保留；
    // 中间平滑过渡，避免硬阈值在真实慢速小运动处"一刀切"导致 warp 失效、
    // 合成退化成原帧 50/50 叠加产生鬼影"来回跳"。
    float softness = smoothstep(0.1, 0.25, flowMag);
    flowPixels *= softness;

    float2 offsetUV = (flowPixels * scale) / size;
    float2 srcUV = clamp(uv - offsetUV, float2(0.0), float2(1.0));

    float4 color = inputTexture.sample(linearSampler, srcUV);
    outputTexture.write(color, gid);
}

/// 前后向一致性检测：对位置 p，理想情况下 F_forward(p) + F_backward(p + F_forward(p)) ≈ 0。
/// 输出标量为残差模长（像素单位），用于 compose 阶段生成光流置信度。
kernel void opticalFlowConsistency(
    texture2d<float, access::sample> flowForward  [[texture(0)]],
    texture2d<float, access::sample> flowBackward [[texture(1)]],
    texture2d<float, access::write>  errorOut     [[texture(2)]],
    uint2 gid [[thread_position_in_grid]])
{
    if (gid.x >= errorOut.get_width() || gid.y >= errorOut.get_height()) {
        return;
    }
    float2 size = float2(errorOut.get_width(), errorOut.get_height());
    float2 uv = (float2(gid) + 0.5) / size;

    float2 fwd = flowForward.sample(linearSampler, uv).xy;
    float2 uvForward = clamp(uv + fwd / size, float2(0.0), float2(1.0));
    float2 bwd = flowBackward.sample(linearSampler, uvForward).xy;

    float residual = length(fwd + bwd);
    errorOut.write(float4(residual, 0.0, 0.0, 0.0), gid);
}

/// 合成：
/// - 颜色一致性：两支 warp 结果颜色差越小越可信；
/// - 光流一致性：前后向残差越小越可信；
/// - 两者取 min 作为综合置信度；
/// - 置信度高时用两支 warp 的线性插值；
/// - 置信度低时退回到**未 warp 的**原始 prev/next 交叉淡化。
///   相比 "nearest in warp space" 方案：
///   (a) 对任意 t（包括 t=0.5）完全对称，不会系统性偏向某一帧；
///   (b) warp 错误区域不再注入"错位纹理"，最坏也只是轻微叠影；
///   (c) 视觉上与前/后真实帧线性衔接，无脉冲/果冻感。
kernel void opticalFlowCompose(
    texture2d<float, access::sample> warpedPrev   [[texture(0)]],
    texture2d<float, access::sample> warpedNext   [[texture(1)]],
    texture2d<float, access::sample> unwarpedPrev [[texture(2)]],
    texture2d<float, access::sample> unwarpedNext [[texture(3)]],
    texture2d<float, access::sample> consistency  [[texture(4)]],
    texture2d<float, access::write>  outputTexture [[texture(5)]],
    constant float &t [[buffer(0)]],
    constant float &flowErrorPivot [[buffer(1)]],
    uint2 gid [[thread_position_in_grid]])
{
    if (gid.x >= outputTexture.get_width() || gid.y >= outputTexture.get_height()) {
        return;
    }
    float2 size = float2(outputTexture.get_width(), outputTexture.get_height());
    float2 uv = (float2(gid) + 0.5) / size;

    float4 a  = warpedPrev.sample(linearSampler, uv);
    float4 b  = warpedNext.sample(linearSampler, uv);
    float4 pa = unwarpedPrev.sample(linearSampler, uv);
    float4 pb = unwarpedNext.sample(linearSampler, uv);

    // 颜色一致性：两支 warp 结果 RGB 差的模长
    float colorErr = length(a.rgb - b.rgb);
    float colorConf = 1.0 - smoothstep(0.08, 0.28, colorErr);

    // 光流一致性：前后向残差（像素单位）
    float flowErr = consistency.sample(linearSampler, uv).r;
    float flowConf = 1.0 - smoothstep(flowErrorPivot * 0.5, flowErrorPivot * 1.5, flowErr);

    float confidence = min(colorConf, flowConf);

    float4 warped   = mix(a, b, t);
    float4 unwarped = mix(pa, pb, t);

    float4 finalColor = mix(unwarped, warped, confidence);
    outputTexture.write(finalColor, gid);
}
