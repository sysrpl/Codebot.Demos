// name: Heat Haze
// description: A scorching day: the air shimmering as it rises off the hot
// description: ground, bending the picture most near the bottom, and the
// description: light a little warm and bleached.
// tags: distortion, weather, heat, shimmer

// How far the shimmer bends the picture near the bottom, in pixels.
const float Bend = 5.0;

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

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    vec2 pixel = 1.0 / iResolution.xy;
    vec2 uv = fragCoord * pixel;
    float t = mod(iTime, 1000.0);

    // Pockets of hot air rising: a pattern drifting upwards, tall and thin,
    // bending the picture mostly from side to side. The hottest air is
    // nearest the ground, so the bottom shimmers most.
    vec2 rising = vec2(uv.x * 45.0, uv.y * 20.0 - t * 2.5);
    vec2 shimmer = vec2(noise2(rising), noise2(rising + 17.3)) - 0.5;
    shimmer += (vec2(noise2(rising * 2.3 + 5.1), noise2(rising * 2.3 + 41.7)) - 0.5) * 0.5;
    float strength = mix(1.0, 0.25, uv.y);
    vec2 at = uv + shimmer * vec2(1.0, 0.4) * Bend * strength * pixel;

    vec3 color = texture2D(iChannel0, at).rgb;

    // Harsh light: warmer, and the shadows a little bleached out.
    color *= vec3(1.05, 1.0, 0.9);
    color = mix(color, vec3(1.0, 0.95, 0.85), 0.08);

    fragColor = vec4(clamp(color, 0.0, 1.0), 1.0);
}
