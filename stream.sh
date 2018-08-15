#!/bin/bash
# Script for live DASH/HLS streaming lossy audio as AAC and/or archiving lossless audio as FLAC  

# Get current timestamp
timestamp=$(date +%s)

#### Set up local output directories
mkdir -p /tmp/flac/
mkdir -p /tmp/flac/$NODE_NAME
mkdir -p /tmp/$NODE_NAME/hls
mkdir -p /tmp/$NODE_NAME/hls/$timestamp
#mkdir -p /tmp/$NODE_NAME/dash
#mkdir -p /tmp/$NODE_NAME/dash/$timestamp
#ln /tmp/$NODE_NAME/dash/$timestamp /tmp/dash_output_dir

# Output timestamp for this (latest) stream
echo $timestamp > /tmp/$NODE_NAME/latest.txt


#### Generate stream segments and manifests, and/or lossless archive

echo "Node started at $timestamp"
echo "Node is named $NODE_NAME and is of type $NODE_TYPE"
## NODE_TYPE set in .env filt to one of: "research"; "debug" (DASH-only); "hls-only"; or default (FLAC+HLS+DASH) 

if [ $NODE_TYPE = "research" ]; then
	SAMPLE_RATE=48000
	STREAM_RATE=48000 ## Is it efficient to specify this so mpegts isn't hit by 4x the uncompressed data?
	echo "Sampling $CHANNELS channels from $AUDIO_HW_ID at $SAMPLE_RATE Hz with bitrate of 32 bits/sample..."
	echo "Asking ffmpeg to write $FLAC_DURATION second $SAMPLE_RATE Hz FLAC files..." 
	## Streaming HLS with FLAC archive 
	nice -n -10 ffmpeg -f alsa -ac $CHANNELS -ar $SAMPLE_RATE -i hw:$AUDIO_HW_ID -ac $CHANNELS -ar $SAMPLE_RATE -sample_fmt s32 -acodec flac \
       -f segment -segment_time "00:00:$FLAC_DURATION.00" -strftime 1 "/tmp/flac/$NODE_NAME/%Y-%m-%d_%H-%M-%S_$NODE_NAME-$SAMPLE_RATE-$CHANNELS.flac" \
       -f segment -segment_list "/tmp/$NODE_NAME/hls/$timestamp/live.m3u8" -segment_list_flags +live -segment_time $SEGMENT_DURATION -segment_format \
       mpegts -ar $STREAM_RATE -ac 2 -acodec aac "/tmp/$NODE_NAME/hls/$timestamp/live%03d.ts" &
elif [ $NODE_TYPE = "debug" ]; then
        SAMPLE_RATE=48000
        STREAM_RATE=48000
	echo "Sampling $CHANNELS channels from $AUDIO_HW_ID at $SAMPLE_RATE Hz with bitrate of 32 bits/sample..."
        echo "Asking ffmpeg to stream DASH via mpegts at $STREAM_RATE Hz..." 
  	## Streaming DASH only via mpegts
  	nice -n -10 ffmpeg -t 0 -f alsa -i hw:$AUDIO_HW_ID -ac $CHANNELS -f mpegts udp://127.0.0.1:1234 &
  	#### Stream with test engine live tools
	## May need to adjust segment length in config_audio.json to match $SEGMENT_DURATION...
  	nice -n -7 ./test-engine-live-tools/bin/live-stream -c ./config_audio.json udp://127.0.0.1:1234 &
elif [ $NODE_TYPE = "hls-only" ]; then
  	SAMPLE_RATE=48000
  	STREAM_RATE=48000
	echo "Sampling $CHANNELS channels from $AUDIO_HW_ID at $SAMPLE_RATE Hz..."
  	echo "Asking ffmpeg to stream only HLS segments at $STREAM_RATE Hz......" 
  	## Streaming HLS only via mpegts
	nice -n -10 ffmpeg -f alsa -ac $CHANNELS -ar $SAMPLE_RATE -thread_queue_size 1024 -i hw:$AUDIO_HW_ID -ac $CHANNELS -f segment -segment_list "/tmp/$NODE_NAME/hls/$timestamp/live.m3u8" -segment_list_flags +live -segment_time $SEGMENT_DURATION -segment_format mpegts -ar $STREAM_RATE -ac 2 -threads 3 -acodec aac "/tmp/$NODE_NAME/hls/$timestamp/live%03d.ts" &
else
	SAMPLE_RATE=48000
	STREAM_RATE=48000
	echo "Sampling $CHANNELS channels from $AUDIO_HW_ID at $SAMPLE_RATE Hz with bitrate of 32 bits/sample..."
	echo "Asking ffmpeg to write $FLAC_DURATION second $SAMPLE_RATE Hz lo-res flac files while streaming in both DASH and HLS..." 
	## Streaming DASH/HLS with low-res flac archive 
	nice -n -10 ffmpeg -f alsa -ac $CHANNELS -ar $SAMPLE_RATE -i hw:$AUDIO_HW_ID -ac $CHANNELS -ar $SAMPLE_RATE -sample_fmt s32 -acodec flac \
       -f segment -segment_time "00:00:$FLAC_DURATION.00" -strftime 1 "/tmp/flac/$NODE_NAME/%Y-%m-%d_%H-%M-%S_$NODE_NAME-$SAMPLE_RATE-$CHANNELS.flac" \
       -f segment -segment_list "/tmp/$NODE_NAME/hls/$timestamp/live.m3u8" -segment_list_flags +live -segment_time $SEGMENT_DURATION -segment_format \
       mpegts -ac 2 -acodec aac "/tmp/$NODE_NAME/hls/$timestamp/live%03d.ts" \
       -f mpegts -ac 2 udp://127.0.0.1:1234 &
	#### Stream with test engine live tools
	## May need to adjust segment length in config_audio.json to match $SEGMENT_DURATION...
	nice -n -7 ./test-engine-live-tools/bin/live-stream -c ./config_audio.json udp://127.0.0.1:1234 &
fi


#
#  Need to pass in timestamp
#
python3 uploads3.py $timestamp
