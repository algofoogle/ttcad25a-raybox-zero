#/!usr/bin/bash

if [ $# -ne 1 ]; then
cat <<EOH
Usage: $0 OUTSPEC
Where:
  OUTSPEC is ONE of:
  - a dir for writing a sequence of PNG files
  - a filename ending in .mp4
  - a filename ending in .gif (animated gif)
  - a double dash (--) for Anton's default behaviour
EOH
exit 1
fi

# H.264 file
function write_h264() {
    #NOTE: This pads the height by 1px (since it assumes 525px tall, but needs to be divisible by 2 for yuv420p):
    ffmpeg -framerate 60 -i frames_out/rbz_basic_frame-%04d.ppm -vf "pad=iw:ih+1" -c:v libx264 -pix_fmt yuv420p -r 60 "$1"
}

function write_animated_gif() {
    #NOTE: -delay 50 sets a 50*10ms (500ms) delay between frames:
    convert -delay 50 rbz_basic_frame-????.ppm +antialias -font Ubuntu-Mono -fill white -pointsize 18 -gravity South -annotate 0 '%f' "$1"
}

function anton_default1() {
    outfile="$HOME/HOST_Documents/rbz-$(date +%Y%m%d_%H%M%S).mp4"
    write_h264 "$outfile" \
        && echo "Wrote output file: $outfile" && ls -alh "$outfile" \
        || echo "Failed to write: $outfile"
}

case "$1" in
    # -- was given: Just do a default per Anton's own local testing:
    --)
        anton_default1
        ;;

    # Target .mp4 filename was given:
    *.mp4)
        write_h264 "$1"
        ;;

    # Target .gif filename was given:
    *.gif)
        write_animated_gif "$1"
        ;;

    # Target subdirectory name for discrete PNG files was given:
    *)
        # Convert PPM sequence to PNG sequence in $1 dir:
        # pushd frames_out
        for f in rbz_basic_frame-????.ppm; do
            echo $f
            convert $f "$1"/$f.png
        done
        # popd
        ;;
esac

