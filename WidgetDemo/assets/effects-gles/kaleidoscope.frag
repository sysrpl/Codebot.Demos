// name: Kaleidoscope
// description: The picture seen through a kaleidoscope: a slice of it
// description: mirrored round and round into a turning, ever changing pattern
// description: of symmetry.
// tags: distortion, fun, pattern, psychedelic, symmetry

// How many mirrored slices make up the circle. Even numbers join up cleanly.
const float Slices = 8.0;

// How fast the pattern turns, in turns a minute.
const float Turning = 1.5;

const float Tau = 6.2831853;

// Folds a point back and forth into 0 to 1, as mirrors do, so however far out
// the pattern reaches it always finds the picture.
vec2 mirrored(vec2 p)
{
    return 1.0 - abs(mod(p, 2.0) - 1.0);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    float aspect = iResolution.x / iResolution.y;
    vec2 p = (fragCoord / iResolution.xy - 0.5) * vec2(aspect, 1.0);
    float t = mod(iTime, 3600.0);

    // Around the middle: how far out, and which way, turning slowly.
    float radius = length(p);
    float angle = atan(p.y, p.x) + t * Turning * Tau / 60.0;

    // Folded into one slice, every other slice the mirror image of the last.
    float slice = Tau / Slices;
    angle = mod(angle, slice);
    angle = abs(angle - slice * 0.5);

    // The slice looks at a part of the picture that wanders slowly, so the
    // pattern keeps changing even when the video holds still.
    vec2 looking = vec2(0.5, 0.5) + vec2(sin(t * 0.13), cos(t * 0.11)) * 0.15;
    vec2 at = looking + vec2(cos(angle), sin(angle)) * radius * 0.8 / vec2(aspect, 1.0);

    fragColor = vec4(texture2D(iChannel0, mirrored(at)).rgb, 1.0);
}
