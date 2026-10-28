# 播放测试素材

`playback.mp4` 是 FFmpeg `testsrc2` 生成的 20 秒 SDR 色块视频，320×180、24 fps、H.264，包含英语／日语标记的 440/880 Hz AAC 单声道音轨和 `subtitles.srt` 转换的内嵌 MOV_TEXT 字幕。没有使用第三方影片。

关键帧间距固定为一秒，因此展示优先的 seek 模式也可以断言第 7 秒的定位结果。相同 SRT 同时用于公开异步外挂字幕加载接口的验收。

重新生成时在仓库根目录运行：

```sh
ffmpeg -hide_banner -loglevel error -y \
  -f lavfi -i 'testsrc2=size=320x180:rate=24:duration=20' \
  -f lavfi -i 'sine=frequency=440:sample_rate=48000:duration=20' \
  -f lavfi -i 'sine=frequency=880:sample_rate=48000:duration=20' \
  -i CinePlayerTests/Fixtures/subtitles.srt \
  -map 0:v -map 1:a -map 2:a -map 3:s \
  -c:v libx264 -preset ultrafast -crf 35 -g 24 -keyint_min 24 -sc_threshold 0 \
  -pix_fmt yuv420p -colorspace bt709 -color_primaries bt709 -color_trc bt709 \
  -c:a aac -b:a 32k -c:s mov_text \
  -metadata:s:a:0 language=eng -metadata:s:a:1 language=jpn -metadata:s:s:0 language=eng \
  -movflags +faststart -t 20 CinePlayerTests/Fixtures/playback.mp4
```
