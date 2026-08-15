#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="${0:A:h}"
OUTPUT_DIR="$SCRIPT_DIR/hello-workday/media"

if ! command -v ffmpeg >/dev/null 2>&1; then
  print -u2 "FFmpeg is required to regenerate the hello-workday abstract media."
  exit 1
fi

mkdir -p "$OUTPUT_DIR"

render_clip() {
  local output="$1"
  local duration="$2"
  local source_filter="$3"
  local video_filter="$4"
  local audio_source="$5"
  local audio_filter="$6"
  local temporary="${output}.rendering"

  /bin/rm -f "$temporary"
  ffmpeg -hide_banner -loglevel error -y \
    -f lavfi -i "$source_filter" \
    -f lavfi -i "$audio_source" \
    -vf "$video_filter" \
    -af "$audio_filter" \
    -c:v libx264 -preset slow -crf 20 -profile:v high -level 3.1 \
    -c:a aac -b:a 96k -ar 48000 \
    -pix_fmt yuv420p -r 24 -t "$duration" -movflags +faststart \
    -metadata creation_time=1970-01-01T00:00:00Z \
    -f mov "$temporary"
  /bin/mv -f "$temporary" "$output"
}

render_clip \
  "$OUTPUT_DIR/shared-win-enter.mov" \
  1.5 \
  "gradients=s=640x360:r=24:d=1.5:c0=0x07111f:c1=0x0f766e:c2=0x67e8f9:n=3:t=spiral:speed=0.12:x0=320:y0=180:x1=640:y1=360:seed=101" \
  "fade=t=in:st=0:d=0.25,eq=saturation=1.08:contrast=1.04" \
  "sine=frequency=440:sample_rate=48000:duration=1.5" \
  "volume=0.035,afade=t=in:st=0:d=0.2,afade=t=out:st=1.1:d=0.4"

render_clip \
  "$OUTPUT_DIR/shared-win-react.mov" \
  1.75 \
  "gradients=s=640x360:r=24:d=1.75:c0=0x0b1024:c1=0x7c3aed:c2=0xf0abfc:c3=0x22d3ee:n=4:t=radial:speed=0.18:x0=520:y0=80:x1=320:y1=180:seed=202" \
  "eq=brightness='0.025*sin(2*PI*t/0.7)':saturation=1.15:contrast=1.05,fade=t=in:st=0:d=0.16" \
  "sine=frequency=659.25:sample_rate=48000:duration=1.75" \
  "volume=0.045,afade=t=in:st=0:d=0.16,afade=t=out:st=1.3:d=0.45"

render_clip \
  "$OUTPUT_DIR/shared-win-exit.mov" \
  1.5 \
  "gradients=s=640x360:r=24:d=1.5:c0=0x22d3ee:c1=0x115e59:c2=0x07111f:n=3:t=circular:speed=0.1:x0=220:y0=210:x1=640:y1=0:seed=303" \
  "eq=saturation=1.05:contrast=1.03,fade=t=out:st=1.1:d=0.4" \
  "sine=frequency=392:sample_rate=48000:duration=1.5" \
  "volume=0.03,afade=t=in:st=0:d=0.2,afade=t=out:st=1.0:d=0.5"

print "Regenerated 3 executable-free abstract clips in examples/packs/hello-workday/media."
print "Review the clips, refresh manifest hashes, then rerun strict validation."
