/* What the core's own layers of Fuse share with the adapter
 * (cinterface.c): the picture, the sound and the last error, each kept
 * where the adapter can take it when a frame ends. */
#ifndef CHIMERA_FUSE_GLUE_H
#define CHIMERA_FUSE_GLUE_H

#include <stdint.h>

/* The picture. A Spectrum's is 320x240 with its border; the Timex machines
 * have a mode with twice the dots across, so theirs is kept at 640x480. */
#define CHIMERA_VIDEO_MAX_W 640
#define CHIMERA_VIDEO_MAX_H 480
extern uint32_t chimera_video[CHIMERA_VIDEO_MAX_W * CHIMERA_VIDEO_MAX_H];
extern int chimera_video_w, chimera_video_h;
/* set when Fuse has finished drawing a frame; the adapter clears it */
extern int chimera_frame_done;

/* The sound Fuse mixed since the adapter last took it: stereo pairs. */
#define CHIMERA_AUDIO_RATE 44100
#define CHIMERA_AUDIO_MAX_PAIRS 4096
extern int16_t chimera_audio[CHIMERA_AUDIO_MAX_PAIRS * 2];
extern int chimera_audio_pairs;

/* What Fuse last said went wrong, for the frontend to show. */
extern char chimera_last_error[512];

/* The machine's own time, in seconds: frames run so far over the frame
 * rate. Fuse asks for "the time" to pace itself and to estimate its speed;
 * here time is what the machine has run. */
extern double chimera_machine_seconds;

#endif
