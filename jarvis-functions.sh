##################
# Main Functions #
##################

# How to install sox?
# MacOSX: http://sourceforge.net/projects/sox/files/sox/14.4.2/
# Linux: "sudo apt-get install sox"

PLAY () { # PLAY () {} Play audio file $1
    [ $platform = "linux" ] && local play_export="AUDIODRIVER=alsa" || local play_export=''
    eval "$play_export play -V1 -q $1"
    if [ "$?" -ne 0 ]; then
        echo "ERROR: play command failed"
        echo "HELP: Verify your speaker in Settings > Audio > Speaker"
        exit 1
    fi
}

RECORD () { # RECORD () {} record microhphone to audio file $1 when sound is detected until silence
    #$verbose && local quiet='' || local quiet='-q'
    [ -n "$2" ] && local timeout="./timeout.sh $2" || local timeout=""
    [ $platform = "linux" ] && export AUDIODRIVER=alsa
    local cmd="$timeout rec -V1 -q -r 16000 -c 1 -b 16 -e signed-integer --endian little $1 silence 1 $min_noise_duration_to_start $min_noise_perc_to_start 1 $min_silence_duration_to_stop $min_silence_level_to_stop trim 0 $max_noise_duration_to_kill"
    $verbose && echo $cmd
    eval $cmd
    if [ "$?" -ne 0 ]; then
        echo "ERROR: rec command failed"
        echo "HELP: Verify your mic in Settings > Audio > Mic"
        exit 1
    fi
}

LISTEN_COMMAND () {
    while true; do
        RECORD "$audiofile" 10
        duration=`sox $audiofile -n stat 2>&1 | sed -n 's#^Length[^0-9]*\([0-9]*\).\([0-9]\)*$#\1\2#p'`
        $verbose && echo "DEBUG: speech duration was $duration (10 = 1 sec)"
        if [ -z "$duration" ] || [ "$duration" = "00" ]; then
            $verbose && echo "DEBUG: timeout, end of conversation" || printf '.'
            #PLAY beep-low.wav
            sleep 1 # BUG here despite timeout mic still busy can't rec again...
            bypass=false
            order='' # clean previous order
            break 2
        elif [ "$duration" -gt 40 ]; then
            $verbose && echo "DEBUG: too long for a command (max 4 secs), ignoring..." || printf '#'
            continue
        else
            break
        fi
    done
}

LISTEN_TRIGGER () {
    while true; do
        RECORD "$audiofile"
        duration=`sox $audiofile -n stat 2>&1 | sed -n 's#^Length[^0-9]*\([0-9]*\).\([0-9]\)*$#\1\2#p'`
        $verbose && echo "DEBUG: speech duration was $duration (10 = 1 sec)"
        if [ "$duration" -lt 2 ]; then
            $verbose && echo "DEBUG: too short for a trigger (min 0.2 max 1.5 sec), ignoring..." || printf '-'
            continue
        elif [ "$duration" -gt 20 ]; then
            $verbose && echo "DEBUG: too long for a trigger (min 0.5 max 1.5 sec), ignoring..." || printf '#'
            sleep 1 # BUG 
            continue
        else
            break
        fi
    done
}

LISTEN () {
    $bypass && LISTEN_COMMAND || LISTEN_TRIGGER
    $verbose && PLAY "$audiofile"
}

TTS () { # TTS () {} Speaks text $1
    $tts_engine'_TTS' "$1"
}
