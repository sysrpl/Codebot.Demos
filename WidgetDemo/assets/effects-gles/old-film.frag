// name: Old Timey Film
// description: Sepia toned and a little darker at the edges, with the grain,
// description: flicker, dust and scratches of a worn reel of film.
// rate: 24
// tags: film, retro, vintage, sepia, movie

// Everything that changes with time changes once a film frame, 24 times a
// second, however often the screen draws, so dust jumps from frame to frame
// the way it did through a projector rather than sliding. The frame count
// wraps every few minutes so the hashes below always work on small numbers.
const float FilmRate = 24.0;

// How much brighter the picture is made, 0.2 for a fifth. The vignette is
// left as dark as it was: the brightening fades out towards the corners.
const float Brighten = 0.2;

// Hashes from arithmetic alone. The usual fract(sin(n) * 43758.5453) loses
// precision on a GPU as n grows.
float hash(float n)
{
    n = fract(n * 0.1031);
    n *= n + 33.33;
    n *= n + n;
    return fract(n);
}

float hash2(vec2 p)
{
    vec3 p3 = fract(vec3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

// Smooth noise along a line: a random height at each whole number, blended
// between the two around x.
float noise(float x)
{
    float i = floor(x);
    float f = fract(x);
    return mix(hash(i), hash(i + 1.0), f * f * (3.0 - 2.0 * f));
}

// Sepia: the brightness the eye sees, laid between a dark brown and a warm
// cream, so blacks are lifted and whites held back the way faded prints are.
vec3 sepia(vec3 color)
{
    float grey = dot(color, vec3(0.2126, 0.7152, 0.0722));
    return mix(vec3(0.10, 0.06, 0.03), vec3(1.0, 0.90, 0.72), grey);
}

// How far into the vignette a point is, 0 in the middle to 1 in the
// corners, measured on a round rather than a stretched shape. It starts about
// a third of the way out, and the corners lose about two thirds of their
// light, like an old lens.
float vignette(vec2 uv)
{
    vec2 d = (uv - 0.5) * vec2(iResolution.x / iResolution.y, 1.0);
    return smoothstep(0.3, 1.0, length(d));
}

// Scratches: long thin dark lines down the film. Each stays near one place
// across the picture for a second or two, wandering, and shaking from side
// to side a few pixels every frame, before it moves somewhere else or goes.
// Along its length it is broken, and the breaks run down the picture as the
// film moves through the gate. Returns how strongly this point is scratched,
// 0 to 1.
float scratches(vec2 uv, float frame)
{
    float mark = 0.0;
    for (int i = 0; i < 3; i++)
    {
        float n = float(i);
        float life = floor((frame + n * 50.0) / (36.0 + 24.0 * n));
        float seed = n * 17.31 + life * 3.7;
        if (hash(seed * 1.3 + 0.7) < 0.6)
        {
            float x = hash(seed)
                + (noise(frame * 0.05 + seed) - 0.5) * 0.01
                + (hash(frame + n * 3.0) - 0.5) * 0.003;
            float width = (1.0 + 1.5 * hash(seed + 2.0)) / iResolution.x;
            float line = 1.0 - smoothstep(0.0, width, abs(uv.x - x));
            float unbroken = smoothstep(0.35, 0.6, noise(uv.y * 5.0 + frame * 0.25 + seed * 7.0));
            mark = max(mark, line * unbroken * (0.5 + 0.5 * hash(seed + 5.0)));
        }
    }
    return mark;
}

// Dust and dirt: a couple of specks a frame, each on screen for that one
// frame only, mostly tiny and ragged edged. Most are dark, dirt on the print;
// a few are light, dust that was on the negative. Returns below zero for
// dark and above for light.
float dirt(vec2 uv, float frame)
{
    float aspect = iResolution.x / iResolution.y;
    float mark = 0.0;
    for (int i = 0; i < 6; i++)
    {
        float seed = frame * 7.0 + float(i) * 13.0;
        if (hash(seed) < 0.3)
        {
            vec2 centre = vec2(hash(seed + 1.0), hash(seed + 2.0));
            float radius = mix(0.002, 0.01, pow(hash(seed + 3.0), 3.0));
            vec2 d = (uv - centre) * vec2(aspect, 1.0);
            float angle = atan(d.y, d.x);
            radius *= 1.0 + 0.25 * sin(angle * 3.0 + seed) + 0.15 * sin(angle * 5.0 + seed * 2.0);
            float speck = 1.0 - smoothstep(radius * 0.6, radius, length(d));
            mark += hash(seed + 4.0) < 0.8 ? -speck : speck;
        }
    }
    return clamp(mark, -1.0, 1.0);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    vec2 uv = fragCoord / iResolution.xy;
    float frame = mod(floor(iTime * FilmRate), 4096.0);

    vec3 color = sepia(texture2D(iChannel0, uv).rgb);

    // The whole picture a touch brighter or darker each frame, as the light
    // through an old projector wavered.
    color *= 1.0 + (hash(frame * 1.37) - 0.5) * 0.08;

    // Grain, different every frame.
    vec2 shift = vec2(hash(frame), hash(frame + 0.5)) * 512.0;
    color += (hash2(fragCoord + shift) - 0.5) * 0.07;

    color = mix(color, vec3(0.06, 0.04, 0.02), scratches(uv, frame) * 0.7);

    float speck = dirt(uv, frame);
    if (speck < 0.0)
        color *= 1.0 + speck * 0.85;
    else
        color = mix(color, vec3(1.0, 0.96, 0.88), speck * 0.7);

    float edge = vignette(uv);
    color *= (1.0 - edge * 0.65) * (1.0 + Brighten * (1.0 - edge));
    fragColor = vec4(clamp(color, 0.0, 1.0), 1.0);
}
