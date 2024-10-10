#ifndef ASTAL_CAVA_H
#define ASTAL_CAVA_H

#include <glib-object.h>

G_BEGIN_DECLS

#define ASTAL_CAVA_TYPE_INPUT (astal_cava_input_get_type())

typedef enum {
    ASTAL_CAVA_INPUT_FIFO,
    ASTAL_CAVA_INPUT_PORTAUDIO,
    ASTAL_CAVA_INPUT_PIPEWIRE,
    ASTAL_CAVA_INPUT_ALSA,
    ASTAL_CAVA_INPUT_PULSE,
    ASTAL_CAVA_INPUT_SNDIO,
    ASTAL_CAVA_INPUT_OSS,
    ASTAL_CAVA_INPUT_JACK,
    ASTAL_CAVA_INPUT_SHMEM,
    ASTAL_CAVA_INPUT_WINSCAP,
} AstalCavaInput;

#define ASTAL_CAVA_TYPE_CAVA (astal_cava_cava_get_type())

G_DECLARE_FINAL_TYPE(AstalCavaCava, astal_cava_cava, ASTAL_CAVA, CAVA, GObject)

AstalCavaCava* astal_cava_cava_get_default();
AstalCavaCava* astal_cava_get_default();

gboolean astal_cava_cava_get_active(AstalCavaCava* self);
void astal_cava_cava_set_active(AstalCavaCava* self, gboolean active);

GArray* astal_cava_cava_get_values(AstalCavaCava* self);

gint astal_cava_cava_get_bars(AstalCavaCava* self);
void astal_cava_cava_set_bars(AstalCavaCava* self, gint bars);

gboolean astal_cava_cava_get_autosens(AstalCavaCava* self);
void astal_cava_cava_set_autosens(AstalCavaCava* self, gboolean autosens);

gboolean astal_cava_cava_get_stereo(AstalCavaCava* self);
void astal_cava_cava_set_stereo(AstalCavaCava* self, gboolean stereo);

gdouble astal_cava_cava_get_noise_reduction(AstalCavaCava* self);
void astal_cava_cava_set_noise_reduction(AstalCavaCava* self, gdouble noise);

gint astal_cava_cava_get_framerate(AstalCavaCava* self);
void astal_cava_cava_set_framerate(AstalCavaCava* self, gint framerate);

AstalCavaInput astal_cava_cava_get_input(AstalCavaCava* self);
void astal_cava_cava_set_input(AstalCavaCava* self, AstalCavaInput input);

gchar* astal_cava_cava_get_source(AstalCavaCava* self);
void astal_cava_cava_set_source(AstalCavaCava* self, const gchar* source);

G_END_DECLS

#endif  // !ASTAL_CAVA_H
