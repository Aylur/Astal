#include <cava/common.h>
#include <gio/gio.h>

#include "astal-cava.h"
#include "cava/config.h"
#include "glib-object.h"
#include "glib.h"

struct _AstalCavaCava {
    GObject parent_instance;

    gint bars;
    gboolean autosens;
    gboolean stereo;
    gdouble noise_reduction;
    gint framerate;
    AstalCavaInput input;
    gchar* audio_source;
    gboolean active;

    GArray* values;
};

typedef struct {
    struct cava_plan plan;
    struct config_params cfg;
    struct audio_data audio_data;
    struct audio_raw audio_raw;
    ptr input_src;

    gboolean constructed;
    GThread* input_thread;
    guint timer_id;

} AstalCavaCavaPrivate;

G_DEFINE_ENUM_TYPE(AstalCavaInput, astal_cava_input,
                   G_DEFINE_ENUM_VALUE(ASTAL_CAVA_INPUT_FIFO, "fifo"),
                   G_DEFINE_ENUM_VALUE(ASTAL_CAVA_INPUT_PORTAUDIO, "portaudio"),
                   G_DEFINE_ENUM_VALUE(ASTAL_CAVA_INPUT_PIPEWIRE, "pipewire"),
                   G_DEFINE_ENUM_VALUE(ASTAL_CAVA_INPUT_ALSA, "alsa"),
                   G_DEFINE_ENUM_VALUE(ASTAL_CAVA_INPUT_PULSE, "pulse"),
                   G_DEFINE_ENUM_VALUE(ASTAL_CAVA_INPUT_SNDIO, "sndio"),
                   G_DEFINE_ENUM_VALUE(ASTAL_CAVA_INPUT_SHMEM, "shmem"),
                   G_DEFINE_ENUM_VALUE(ASTAL_CAVA_INPUT_WINSCAP, "winscap"));

G_DEFINE_TYPE_WITH_PRIVATE(AstalCavaCava, astal_cava_cava, G_TYPE_OBJECT)

typedef enum {
    ASTAL_CAVA_CAVA_PROP_VALUES = 1,
    ASTAL_CAVA_CAVA_PROP_ACTIVE,
    ASTAL_CAVA_CAVA_PROP_BARS,
    ASTAL_CAVA_CAVA_PROP_AUTOSENS,
    ASTAL_CAVA_CAVA_PROP_STEREO,
    ASTAL_CAVA_CAVA_PROP_NOISE,
    ASTAL_CAVA_CAVA_PROP_FRAMERATE,
    ASTAL_CAVA_CAVA_PROP_INPUT,
    ASTAL_CAVA_CAVA_PROP_SOURCE,
    ASTAL_CAVA_CAVA_N_PROPERTIES
} AstalCavaProperties;

static GParamSpec* astal_cava_cava_properties[ASTAL_CAVA_CAVA_N_PROPERTIES] = {
    NULL,
};

static gboolean exec_cava(AstalCavaCava* self) {
    AstalCavaCavaPrivate* priv = astal_cava_cava_get_instance_private(self);

    pthread_mutex_lock(&priv->audio_data.lock);
    cava_execute(priv->audio_data.cava_in, priv->audio_data.samples_counter,
                 priv->audio_raw.cava_out, &priv->plan);
    if (priv->audio_data.samples_counter > 0) priv->audio_data.samples_counter = 0;
    pthread_mutex_unlock(&priv->audio_data.lock);

    g_array_remove_range(self->values, 0, priv->audio_raw.number_of_bars);
    g_array_insert_vals(self->values, 0, priv->audio_raw.cava_out, priv->audio_raw.number_of_bars);

    g_object_notify(G_OBJECT(self), "values");

    return G_SOURCE_CONTINUE;
}

static void astal_cava_cava_cleanup(AstalCavaCava* self) {
    AstalCavaCavaPrivate* priv = astal_cava_cava_get_instance_private(self);

    g_source_remove(priv->timer_id);
    pthread_mutex_lock(&priv->audio_data.lock);
    priv->audio_data.terminate = 1;
    pthread_mutex_unlock(&priv->audio_data.lock);
    g_thread_join(priv->input_thread);

    cava_destroy(&priv->plan);

    g_free(priv->audio_data.cava_in);
    g_free(priv->audio_data.source);

    g_free(priv->cfg.audio_source);
    g_free(priv->cfg.raw_target);
    g_free(priv->cfg.data_format);
}

static void astal_cava_cava_start(AstalCavaCava* self) {
    AstalCavaCavaPrivate* priv = astal_cava_cava_get_instance_private(self);

    priv->cfg = (struct config_params){
        .inAtty = 0,
        .output = OUTPUT_RAW,
        .raw_target = strdup("/dev/stdout"),
        .data_format = strdup("binary"),

        .fixedbars = self->bars,
        .autosens = self->autosens,
        .stereo = self->stereo,
        .noise_reduction = self->noise_reduction,
        .framerate = self->framerate,
        .input = (enum input_method)self->input,

        // maybe make some of them configurable
        .channels = 2,
        .lower_cut_off = 50,
        .upper_cut_off = 10000,

        // not needed in this lib
        .mono_opt = AVERAGE,
        .waves = 0,
        .userEQ = NULL,
        .userEQ_keys = 0,
        .userEQ_enabled = 0,
        .samplerate = 44100,
        .samplebits = 16,
        .waveform = 0,
        .monstercat = 0,
        .sens = 1,
        .autoconnect = 2,
        .reverse = 0,
        .sleep_timer = 0,
        .show_idle_bar_heads = 1,
        .continuous_rendering = 0,
        .sdl_width = 1000,
        .sdl_height = 500,
        .sdl_x = -1,
        .sdl_y = -1,
        .sdl_full_screen = 0,
        .draw_and_quit = 0,
        .zero_test = 0,
        .non_zero_test = 0,
        .sync_updates = 0,
        .disable_blanking = 1,
        .bar_height = 32,
        .col = 0,
        .bgcol = 0,
        .autobars = 0,
        .raw_format = FORMAT_BINARY,
        .ascii_range = 1000,
        .bit_format = 16,
        .gradient = 0,
        .gradient_count = 0,
        .bar_width = 2,
        .bar_spacing = 1,
        .xaxis = NONE,
        .orientation = ORIENT_BOTTOM,
        .color = NULL,
        .bcolor = NULL,
        .gradient_colors = NULL,
        .vertex_shader = NULL,
        .fragment_shader = NULL,
        .bar_delim = ';',
        .frame_delim = '\n',
    };

    if (g_strcmp0(self->audio_source, "auto") == 0) {
        switch (priv->cfg.input) {
            case INPUT_ALSA:
                priv->cfg.audio_source = g_strdup("hw:Loopback,1");
                break;
            case INPUT_FIFO:
                priv->cfg.audio_source = g_strdup("/tmp/mpd.fifo");
                break;
            case INPUT_PULSE:
                priv->cfg.audio_source = g_strdup("auto");
                break;
            case INPUT_PIPEWIRE:
                priv->cfg.audio_source = g_strdup("auto");
                break;
            case INPUT_SNDIO:
                priv->cfg.audio_source = g_strdup("default");
                break;
            case INPUT_OSS:
                priv->cfg.audio_source = g_strdup("/dev/dsp");
                break;
            case INPUT_JACK:
                priv->cfg.audio_source = g_strdup("default");
                break;
            case INPUT_SHMEM:
                priv->cfg.audio_source = g_strdup("/squeezelite-00:00:00:00:00:00");
                break;
            case INPUT_PORTAUDIO:
                priv->cfg.audio_source = g_strdup("auto");
                break;
            default:
                g_critical("unsupported audio source");
        }
    } else {
        priv->cfg.audio_source = g_strdup(self->audio_source);
    }

    priv->audio_data = (struct audio_data){
        .cava_in = calloc(BUFFER_SIZE * priv->cfg.channels * 8, sizeof(gdouble)),
        .input_buffer_size = BUFFER_SIZE * priv->cfg.channels,
        .cava_buffer_size = BUFFER_SIZE * priv->cfg.channels * 8,
        .format = -1,
        .rate = 0,
        .channels = priv->cfg.channels,
        .source = g_strdup(priv->cfg.audio_source),
        .terminate = 0,
        .samples_counter = 0,
        .IEEE_FLOAT = 0,
        .suspendFlag = false,
    };

    priv->input_src = get_input(&priv->audio_data, &priv->cfg);

    audio_raw_init(&priv->audio_data, &priv->audio_raw, &priv->cfg, &priv->plan);

    priv->input_thread = g_thread_new("cava_input", priv->input_src, &priv->audio_data);

    priv->timer_id = g_timeout_add(1000 / priv->cfg.framerate, G_SOURCE_FUNC(exec_cava), self);
}

static void astal_cava_cava_restart(AstalCavaCava* self) {
    if (!self->active) return;
    astal_cava_cava_cleanup(self);
    astal_cava_cava_start(self);
}

gboolean astal_cava_cava_get_active(AstalCavaCava* self) { return self->active; }

void astal_cava_cava_set_active(AstalCavaCava* self, gboolean active) {
    if (self->active == active) return;
    AstalCavaCavaPrivate* priv = astal_cava_cava_get_instance_private(self);

    self->active = active;

    if (!priv->constructed) return;
    if (!active)
        astal_cava_cava_cleanup(self);
    else
        astal_cava_cava_start(self);
}

/**
 * astal_cava_cava_get_values
 * @self: the AstalCavaCava object
 *
 * Returns: (transfer none) (element-type gdouble): a list of values
 *
 */
GArray* astal_cava_cava_get_values(AstalCavaCava* self) { return self->values; }

gint astal_cava_cava_get_bars(AstalCavaCava* self) { return self->bars; }

void astal_cava_cava_set_bars(AstalCavaCava* self, gint bars) {
    AstalCavaCavaPrivate* priv = astal_cava_cava_get_instance_private(self);
    self->bars = bars;
    if (priv->constructed) {
        g_array_set_size(self->values, self->bars);
        astal_cava_cava_restart(self);
    }
}

gboolean astal_cava_cava_get_autosens(AstalCavaCava* self) { return self->autosens; }

void astal_cava_cava_set_autosens(AstalCavaCava* self, gboolean autosens) {
    AstalCavaCavaPrivate* priv = astal_cava_cava_get_instance_private(self);
    self->autosens = autosens;
    if (priv->constructed) astal_cava_cava_restart(self);
}

gboolean astal_cava_cava_get_stereo(AstalCavaCava* self) { return self->stereo; }

void astal_cava_cava_set_stereo(AstalCavaCava* self, gboolean stereo) {
    AstalCavaCavaPrivate* priv = astal_cava_cava_get_instance_private(self);
    self->stereo = stereo;
    if (priv->constructed) astal_cava_cava_restart(self);
}

gdouble astal_cava_cava_get_noise_reduction(AstalCavaCava* self) { return self->noise_reduction; }

void astal_cava_cava_set_noise_reduction(AstalCavaCava* self, gdouble noise) {
    AstalCavaCavaPrivate* priv = astal_cava_cava_get_instance_private(self);
    self->noise_reduction = noise;
    if (priv->constructed) astal_cava_cava_restart(self);
}

gint astal_cava_cava_get_framerate(AstalCavaCava* self) { return self->framerate; }

void astal_cava_cava_set_framerate(AstalCavaCava* self, gint framerate) {
    AstalCavaCavaPrivate* priv = astal_cava_cava_get_instance_private(self);
    self->framerate = framerate;
    if (priv->constructed) astal_cava_cava_restart(self);
}

AstalCavaInput astal_cava_cava_get_input(AstalCavaCava* self) { return self->input; }

void astal_cava_cava_set_input(AstalCavaCava* self, AstalCavaInput input) {
    AstalCavaCavaPrivate* priv = astal_cava_cava_get_instance_private(self);
    self->input = input;
    if (priv->constructed) astal_cava_cava_restart(self);
}

gchar* astal_cava_cava_get_source(AstalCavaCava* self) { return self->audio_source; }

void astal_cava_cava_set_source(AstalCavaCava* self, const gchar* source) {
    AstalCavaCavaPrivate* priv = astal_cava_cava_get_instance_private(self);
    g_free(self->audio_source);
    self->audio_source = g_strdup(source);
    if (priv->constructed) astal_cava_cava_restart(self);
}

static void astal_cava_cava_set_property(GObject* object, guint property_id, const GValue* value,
                                         GParamSpec* pspec) {
    AstalCavaCava* self = ASTAL_CAVA_CAVA(object);

    switch (property_id) {
        case ASTAL_CAVA_CAVA_PROP_BARS:
            astal_cava_cava_set_bars(self, g_value_get_int(value));
            break;
        case ASTAL_CAVA_CAVA_PROP_ACTIVE:
            astal_cava_cava_set_active(self, g_value_get_boolean(value));
            break;
        case ASTAL_CAVA_CAVA_PROP_AUTOSENS:
            astal_cava_cava_set_autosens(self, g_value_get_boolean(value));
            break;
        case ASTAL_CAVA_CAVA_PROP_NOISE:
            astal_cava_cava_set_noise_reduction(self, g_value_get_double(value));
            break;
        case ASTAL_CAVA_CAVA_PROP_STEREO:
            astal_cava_cava_set_stereo(self, g_value_get_boolean(value));
            break;
        case ASTAL_CAVA_CAVA_PROP_FRAMERATE:
            astal_cava_cava_set_framerate(self, g_value_get_int(value));
            break;
        case ASTAL_CAVA_CAVA_PROP_INPUT:
            astal_cava_cava_set_input(self, g_value_get_enum(value));
            break;
        case ASTAL_CAVA_CAVA_PROP_SOURCE:
            g_free(self->audio_source);
            astal_cava_cava_set_source(self, g_value_get_string(value));
            break;
        default:
            G_OBJECT_WARN_INVALID_PROPERTY_ID(object, property_id, pspec);
            break;
    }
}

static void astal_cava_cava_get_property(GObject* object, guint property_id, GValue* value,
                                         GParamSpec* pspec) {
    AstalCavaCava* self = ASTAL_CAVA_CAVA(object);

    switch (property_id) {
        case ASTAL_CAVA_CAVA_PROP_ACTIVE:
            g_value_set_boolean(value, self->active);
            break;
        case ASTAL_CAVA_CAVA_PROP_BARS:
            g_value_set_int(value, self->bars);
            break;
        case ASTAL_CAVA_CAVA_PROP_VALUES:
            g_value_set_pointer(value, self->values);
            break;
        case ASTAL_CAVA_CAVA_PROP_AUTOSENS:
            g_value_set_boolean(value, self->autosens);
            break;
        case ASTAL_CAVA_CAVA_PROP_NOISE:
            g_value_set_double(value, self->noise_reduction);
            break;
        case ASTAL_CAVA_CAVA_PROP_STEREO:
            g_value_set_boolean(value, self->stereo);
            break;
        case ASTAL_CAVA_CAVA_PROP_FRAMERATE:
            g_value_set_int(value, self->framerate);
            break;
        case ASTAL_CAVA_CAVA_PROP_INPUT:
            g_value_set_enum(value, self->input);
            break;
        case ASTAL_CAVA_CAVA_PROP_SOURCE:
            g_value_set_string(value, self->audio_source);
            break;
        default:
            G_OBJECT_WARN_INVALID_PROPERTY_ID(object, property_id, pspec);
            break;
    }
}

static void astal_cava_cava_constructed(GObject* object) {
    AstalCavaCava* self = ASTAL_CAVA_CAVA(object);
    AstalCavaCavaPrivate* priv = astal_cava_cava_get_instance_private(self);

    gdouble* data = calloc(self->bars, sizeof(gdouble));
    memset(data, 0, self->bars * sizeof(gdouble));
    self->values = g_array_new_take(data, self->bars, TRUE, sizeof(gdouble));

    priv->constructed = true;

    if (self->active) astal_cava_cava_start(self);
}

static void astal_cava_cava_init(AstalCavaCava* self) {
    AstalCavaCavaPrivate* priv = astal_cava_cava_get_instance_private(self);
    priv->constructed = false;
}

/**
 * astal_cava_get_default
 *
 * gets the default Cava object.
 *
 * Returns: (nullable) (transfer none):
 */
AstalCavaCava* astal_cava_get_default() { return astal_cava_cava_get_default(); }

/**
 * astal_cava_cava_get_default
 *
 * gets the default Cava object.
 *
 * Returns: (nullable) (transfer none):
 */
AstalCavaCava* astal_cava_cava_get_default() {
    static AstalCavaCava* self = NULL;

    if (self == NULL) self = g_object_new(ASTAL_CAVA_TYPE_CAVA, NULL);

    return self;
}

static void astal_cava_cava_dispose(GObject* object) {
    AstalCavaCava* self = ASTAL_CAVA_CAVA(object);

    if (self->active) astal_cava_cava_cleanup(self);
    G_OBJECT_CLASS(astal_cava_cava_parent_class)->dispose(object);
}

static void astal_cava_cava_finalize(GObject* object) {
    AstalCavaCava* self = ASTAL_CAVA_CAVA(object);

    g_array_free(self->values, TRUE);

    G_OBJECT_CLASS(astal_cava_cava_parent_class)->finalize(object);
}

static void astal_cava_cava_class_init(AstalCavaCavaClass* class) {
    GObjectClass* object_class = G_OBJECT_CLASS(class);
    object_class->get_property = astal_cava_cava_get_property;
    object_class->set_property = astal_cava_cava_set_property;
    object_class->constructed = astal_cava_cava_constructed;
    object_class->dispose = astal_cava_cava_dispose;
    object_class->finalize = astal_cava_cava_finalize;

    /**
     * AstalCavaCava:values: (type GArray(gdouble))
     *
     * A list of values, each represent the height of one bar. The values are generally between 0 and 1 but can overshoot occasionally, in which case the sensitivity will be decreased automatically if [property@AstalCava.Cava:autosens] is set. The array will have [property@AstalCava.Cava:bars] entries. If [property@AstalCava.Cava:stereo] is set, the first half of the array will represent the left channel and the second half the right channel, so there will be only bars/2 bars per channel. If the number of bars is odd, the last value will be 0.
     */
    astal_cava_cava_properties[ASTAL_CAVA_CAVA_PROP_VALUES] =
        g_param_spec_pointer("values", "values", "a list of values", G_PARAM_READABLE);
    /**
    * AstalCavaCava:active:
    *
    * whether or not the audio capture and visualization is running. if false the values array will not be updated.
    */
    astal_cava_cava_properties[ASTAL_CAVA_CAVA_PROP_ACTIVE] = g_param_spec_boolean(
        "active", "active", "active", TRUE, G_PARAM_READWRITE | G_PARAM_CONSTRUCT);
    /**
    * AstalCavaCava:bars:
    *
    * the number of bars the visualizer should create. 
    */
    astal_cava_cava_properties[ASTAL_CAVA_CAVA_PROP_BARS] =
        g_param_spec_int("bars", "bars", "number of bars per channel", 1, G_MAXINT, 20,
                         G_PARAM_READWRITE | G_PARAM_CONSTRUCT);
    /**
     * AstalCavaCava:autosens:
     *
     * When set, the sensitivity will automatically be adjusted.
    */
    astal_cava_cava_properties[ASTAL_CAVA_CAVA_PROP_AUTOSENS] =
        g_param_spec_boolean("autosens", "autosens", "dynamically adjust sensitivity", TRUE,
                             G_PARAM_READWRITE | G_PARAM_CONSTRUCT);
    /**
    * AstalCavaCava:cava:
    *
    * When set the output will contain visualization data for both channels.
    */
    astal_cava_cava_properties[ASTAL_CAVA_CAVA_PROP_STEREO] = g_param_spec_boolean(
        "stereo", "stereo", "stereo", FALSE, G_PARAM_READWRITE | G_PARAM_CONSTRUCT);
    astal_cava_cava_properties[ASTAL_CAVA_CAVA_PROP_NOISE] =
        g_param_spec_double("noise_reduction", "noise_reduction", "noise reduction", 0, 1,
                            0.77, G_PARAM_READWRITE | G_PARAM_CONSTRUCT);
    astal_cava_cava_properties[ASTAL_CAVA_CAVA_PROP_FRAMERATE] =
        g_param_spec_int("framerate", "framerate", "framerate", 1, G_MAXINT, 60,
                         G_PARAM_READWRITE | G_PARAM_CONSTRUCT);
    /**
    * AstalCavaCava:input: (type AstalCavaInput)
    *
    * specifies which audio server should be used.
    */
    astal_cava_cava_properties[ASTAL_CAVA_CAVA_PROP_INPUT] =
        g_param_spec_enum("input", "input", "input", ASTAL_CAVA_TYPE_INPUT,
                          ASTAL_CAVA_INPUT_PIPEWIRE, G_PARAM_READWRITE | G_PARAM_CONSTRUCT);
    /**
    * AstalCavaCava:source:
    *
    * specifies which audio source should be used. Refer to the cava docs on how to use this property.
    */
    astal_cava_cava_properties[ASTAL_CAVA_CAVA_PROP_SOURCE] = g_param_spec_string(
        "source", "source", "source", "auto", G_PARAM_READWRITE | G_PARAM_CONSTRUCT);
    g_object_class_install_properties(object_class, ASTAL_CAVA_CAVA_N_PROPERTIES,
                                      astal_cava_cava_properties);
}
