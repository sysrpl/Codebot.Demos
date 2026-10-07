// name: Predator Vision
// description: The hunter's heat vision from Predator: the scene in blotchy
// description: bands of blue, green, yellow and red by warmth, rippling as if
// description: seen through shimmering air.
// tags: sci-fi, heat, movie, alien

// How many bands of heat the picture is cut into.
const float Bands = 9.0;

// How far the shimmer bends the picture, as a part of its width.
const float Shimmer = 0.004;

float hash2(vec2 p)
{
    vec3 p3 = fract(vec3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

float noise2(vec2 p)
{
    vec2 i = floor(p);
    vec2 f = fract(p);
    vec2 u = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash2(i), hash2(i + vec2(1.0, 0.0)), u.x),
               mix(hash2(i + vec2(0.0, 1.0)), hash2(i + 1.0), u.x), u.y);
}

// The film's palette: deep blue for cold, through cyan, green and yellow,
// to red for the hottest.
vec3 palette(float t)
{
    t = clamp(t, 0.0, 1.0) * 4.0;
    if (t < 1.0) return mix(vec3(0.0, 0.0, 0.35), vec3(0.0, 0.45, 1.0), t);
    if (t < 2.0) return mix(vec3(0.0, 0.45, 1.0), vec3(0.1, 1.0, 0.2), t - 1.0);
    if (t < 3.0) return mix(vec3(0.1, 1.0, 0.2), vec3(1.0, 1.0, 0.0), t - 2.0);
    return mix(vec3(1.0, 1.0, 0.0), vec3(1.0, 0.1, 0.0), t - 3.0);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    vec2 pixel = 1.0 / iResolution.xy;
    vec2 uv = fragCoord * pixel;

    // Shimmer: the picture bent by slow waves drifting through it.
    float t = mod(iTime, 1000.0);
    vec2 bend = vec2(noise2(uv * vec2(20.0, 12.0) + vec2(0.0, t * 1.5)),
                     noise2(uv * vec2(20.0, 12.0) + vec2(t * 1.2, 5.0))) - 0.5;
    vec2 at = uv + bend * Shimmer * 2.0;

    // Heat, guessed as brightness with warm colours warmer, from a softened
    // picture so the bands come out as blotches rather than speckle.
    vec3 color = vec3(0.0);
    for (int y = -1; y <= 1; y++)
        for (int x = -1; x <= 1; x++)
            color += texture2D(iChannel0, at + vec2(x, y) * 3.0 * pixel).rgb;
    color /= 9.0;
    float level = dot(color, vec3(0.2126, 0.7152, 0.0722));
    float warmth = clamp((color.r - color.b) * 0.8, 0.0, 1.0);
    float heat = clamp(level * 0.7 + warmth * 0.45, 0.0, 1.0);

    // Cut into bands, each a flat colour.
    heat = floor(heat * Bands) / (Bands - 1.0);
    fragColor = vec4(palette(heat), 1.0);
}
