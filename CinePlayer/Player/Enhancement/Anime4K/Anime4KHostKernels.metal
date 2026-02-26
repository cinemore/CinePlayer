#include <metal_stdlib>
using namespace metal;

struct YUVConversionParams {
    uint isVideoRange;
};

// A/B 对比用 linear 采样，降低 GPU 成本
constexpr sampler linearSampler(coord::normalized, address::clamp_to_edge, filter::linear);

kernel void BGRA8ToRGBA(texture2d<float, access::read> input [[texture(0)]],
                        texture2d<float, access::write> output [[texture(1)]],
                        uint2 gid [[thread_position_in_grid]]) {
    if (gid.x >= output.get_width() || gid.y >= output.get_height()) {
        return;
    }
    output.write(input.read(gid), gid);
}

kernel void YUV420BiPlanarToRGBA(texture2d<float, access::read> yTex [[texture(0)]],
                                 texture2d<float, access::read> uvTex [[texture(1)]],
                                 texture2d<float, access::write> output [[texture(2)]],
                                 constant YUVConversionParams& params [[buffer(0)]],
                                 uint2 gid [[thread_position_in_grid]]) {
    if (gid.x >= output.get_width() || gid.y >= output.get_height()) {
        return;
    }

    float y = yTex.read(gid).r;
    float2 uv = uvTex.read(uint2(gid.x / 2, gid.y / 2)).rg;

    if (params.isVideoRange == 1) {
        y = max(0.0, (y - (16.0 / 255.0)) * (255.0 / 219.0));
        uv = (uv - float2(128.0 / 255.0)) * (255.0 / 224.0);
    } else {
        uv = uv - float2(0.5, 0.5);
    }

    float r = y + 1.5748 * uv.y;
    float g = y - 0.1873 * uv.x - 0.4681 * uv.y;
    float b = y + 1.8556 * uv.x;

    output.write(float4(clamp(float3(r, g, b), 0.0, 1.0), 1.0), gid);
}

// P010：10-bit Y/CbCr，16-bit 存储（高 10 位有效），video range Y 64–940、CbCr 64–960
kernel void YUV420P010BiPlanarToRGBA(texture2d<float, access::read> yTex [[texture(0)]],
                                      texture2d<float, access::read> uvTex [[texture(1)]],
                                      texture2d<float, access::write> output [[texture(2)]],
                                      constant YUVConversionParams& params [[buffer(0)]],
                                      uint2 gid [[thread_position_in_grid]]) {
    if (gid.x >= output.get_width() || gid.y >= output.get_height()) {
        return;
    }
    // r16Unorm 读出 [0,1]，P010 为 10bit 左对齐到 16bit，故 value_10bit = read * 65535 / 64
    float y16 = yTex.read(gid).r;
    float2 uv16 = uvTex.read(uint2(gid.x / 2, gid.y / 2)).rg;
    float y10 = clamp(y16 * 65535.0 / 64.0, 0.0, 1023.0);
    float2 uv10 = clamp(uv16 * 65535.0 / 64.0, 0.0, 1023.0);

    float y;
    float2 uv;
    if (params.isVideoRange == 1) {
        y = max(0.0, (y10 - 64.0) / 876.0);   // 64–940 -> [0,1]
        uv = (uv10 - 512.0) / 896.0;           // 64–960, center 512
    } else {
        y = y10 / 1023.0;
        uv = uv10 / 1023.0 - 0.5;              // full range 0–1023 -> CbCr [-0.5,0.5]
    }

    float r = y + 1.5748 * uv.y;
    float g = y - 0.1873 * uv.x - 0.4681 * uv.y;
    float b = y + 1.8556 * uv.x;

    output.write(float4(clamp(float3(r, g, b), 0.0, 1.0), 1.0), gid);
}

kernel void YUV420PlanarToRGBA(texture2d<float, access::read> yTex [[texture(0)]],
                               texture2d<float, access::read> uTex [[texture(1)]],
                               texture2d<float, access::read> vTex [[texture(2)]],
                               texture2d<float, access::write> output [[texture(3)]],
                               constant YUVConversionParams& params [[buffer(0)]],
                               uint2 gid [[thread_position_in_grid]]) {
    if (gid.x >= output.get_width() || gid.y >= output.get_height()) {
        return;
    }

    float y = yTex.read(gid).r;
    float u = uTex.read(uint2(gid.x / 2, gid.y / 2)).r;
    float v = vTex.read(uint2(gid.x / 2, gid.y / 2)).r;
    float2 uv = float2(u, v);

    if (params.isVideoRange == 1) {
        y = max(0.0, (y - (16.0 / 255.0)) * (255.0 / 219.0));
        uv = (uv - float2(128.0 / 255.0)) * (255.0 / 224.0);
    } else {
        uv = uv - float2(0.5, 0.5);
    }

    float r = y + 1.5748 * uv.y;
    float g = y - 0.1873 * uv.x - 0.4681 * uv.y;
    float b = y + 1.8556 * uv.x;

    output.write(float4(clamp(float3(r, g, b), 0.0, 1.0), 1.0), gid);
}

kernel void ABCompareSplit(texture2d<float, access::sample> original [[texture(0)]],
                           texture2d<float, access::sample> enhanced [[texture(1)]],
                           texture2d<float, access::write> output [[texture(2)]],
                           constant uint& lineHalfWidth [[buffer(0)]],
                           uint2 gid [[thread_position_in_grid]]) {
    if (gid.x >= output.get_width() || gid.y >= output.get_height()) {
        return;
    }

    float2 uv = (float2(gid) + float2(0.5)) / float2(output.get_width(), output.get_height());
    float4 originalColor = original.sample(linearSampler, uv);
    float4 enhancedColor = enhanced.sample(linearSampler, uv);
    uint splitX = output.get_width() / 2;
    float4 color = gid.x < splitX ? originalColor : enhancedColor;

    if (abs(int(gid.x) - int(splitX)) <= int(max(1u, lineHalfWidth))) {
        color = float4(1.0, 0.15, 0.15, 1.0);
    }

    output.write(color, gid);
}

kernel void DirectTransfer(texture2d<float, access::read> input [[texture(0)]],
                           texture2d<float, access::write> output [[texture(1)]],
                           uint2 gid [[thread_position_in_grid]]) {
    if (gid.x >= output.get_width() || gid.y >= output.get_height()) {
        return;
    }
    output.write(input.read(gid), gid);
}

kernel void CenterResize(texture2d<float, access::sample> input [[texture(0)]],
                         texture2d<float, access::write> output [[texture(1)]],
                         uint2 gid [[thread_position_in_grid]]) {
    float inW = input.get_width();
    float inH = input.get_height();
    float outW = output.get_width();
    float outH = output.get_height();
    float scale = min(outW / inW, outH / inH);
    float outValidW = round(inW * scale);
    float outValidH = round(inH * scale);
    float outPadW = round((outW - outValidW) / 2.0);
    float outPadH = round((outH - outValidH) / 2.0);
    float2 nPos = float2((float(gid.x) - outPadW + 0.5) / outValidW,
                         (float(gid.y) - outPadH + 0.5) / outValidH);
    if (nPos.x < 0 || nPos.x > 1 || nPos.y < 0 || nPos.y > 1) {
        output.write(float4(0), gid);
        return;
    }
    output.write(input.sample(linearSampler, nPos), gid);
}
