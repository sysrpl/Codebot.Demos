// name: Thermal Camera
// description: Seen through a thermal imaging camera: the picture as heat,
// description: from cold black and purple through red and orange to white
// description: hot, a little soft and blocky, with a scale down the side.
// tags: sci-fi, heat, camera, colour, color

// The camera's own resolution, far lower than the TV's.
const vec2 Sensor = vec2(480.0, 270.0);

const float FrameRate = 30.0;

float hash2(vec2 p)
{
    vec3 p3 = fract(vec3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

// The ironbow palette most thermal cameras use, cold to hot.
vec3 ironbow(float t)
{
    t = clamp(t, 0.0, 1.0) * 6.0;
    if (t < 1.0) return mix(vec3(0.0, 0.0, 0.0), vec3(0.12, 0.0, 0.4), t);
    if (t < 2.0) return mix(vec3(0.12, 0.0, 0.4), vec3(0.55, 0.0, 0.6), t - 1.0);
    if (t < 3.0) return mix(vec3(0.55, 0.0, 0.6), vec3(0.9, 0.15, 0.15), t - 2.0);
    if (t < 4.0) return mix(vec3(0.9, 0.15, 0.15), vec3(1.0, 0.5, 0.0), t - 3.0);
    if (t < 5.0) return mix(vec3(1.0, 0.5, 0.0), vec3(1.0, 0.9, 0.3), t - 4.0);
    return mix(vec3(1.0, 0.9, 0.3), vec3(1.0), t - 5.0);
}

// A video has no heat in it, so it is guessed: brighter is warmer, and warm
// colours, skin, fire and lamps, warmer still.
float heat(vec3 color)
{
    float level = dot(color, vec3(0.2126, 0.7152, 0.0722));
    float warmth = clamp((color.r - color.b) * 0.8, 0.0, 1.0);
    return smoothstep(0.05, 0.95, level * 0.65 + warmth * 0.45);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    vec2 pixel = 1.0 / iResolution.xy;
    vec2 uv = fragCoord * pixel;

    // The scale: a bar of the palette down the right hand side, framed.
    vec2 bar = vec2(0.955, 0.2);
    vec2 barSize = vec2(0.012, 0.6);
    vec2 inBar = (uv - bar) / barSize;
    if (inBar.x >= -0.15 && inBar.x <= 1.15 && inBar.y >= -0.02 && inBar.y <= 1.02)
    {
        bool inside = inBar.x >= 0.0 && inBar.x <= 1.0 && inBar.y >= 0.0 && inBar.y <= 1.0;
        fragColor = vec4(inside ? ironbow(inBar.y) : vec3(0.85), 1.0);
        return;
    }

    // The sensor's pixel, its heat taken from a few points around it, so the
    // picture is both blocky and soft, as a thermal camera's is.
    vec2 cell = (floor(uv * Sensor) + 0.5) / Sensor;
    vec2 spread = pixel * 2.0;
    vec3 color = (texture2D(iChannel0, cell).rgb * 2.0
        + texture2D(iChannel0, cell + vec2(spread.x, 0.0)).rgb
        + texture2D(iChannel0, cell - vec2(spread.x, 0.0)).rgb
        + texture2D(iChannel0, cell + vec2(0.0, spread.y)).rgb
        + texture2D(iChannel0, cell - vec2(0.0, spread.y)).rgb) / 6.0;
    float t = heat(color);

    // The sensor's noise, which changes every frame.
    float frame = mod(floor(iTime * FrameRate), 4096.0);
    t += (hash2(floor(uv * Sensor) + frame * 17.0) - 0.5) * 0.04;

    fragColor = vec4(ironbow(t), 1.0);
}
