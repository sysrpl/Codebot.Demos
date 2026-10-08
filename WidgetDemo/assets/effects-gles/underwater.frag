// name: Underwater
// description: Seen from under the sea: the picture swaying with the water,
// description: tinted blue-green and dimmer with depth, and rippling nets of
// description: sunlight playing over everything.
// tags: distortion, fun, water, sea, blue

// How far the water sways the picture, as a part of its size.
const float Sway = 0.004;

const vec3 Water = vec3(0.0, 0.25, 0.35);

// Caustics: the bright rippling network sunlight makes through waves. Waves
// of sines are fed back into themselves a few times, and the places where
// they bunch together are lit.
float caustics(vec2 uv, float t)
{
    vec2 p = mod(uv * 6.2831853 * 1.5, 6.2831853) - 250.0;
    vec2 i = p;
    float c = 1.0;
    float intensity = 0.005;
    for (int n = 0; n < 4; n++)
    {
        float tn = t * (1.0 - 3.5 / float(n + 1));
        i = p + vec2(cos(tn - i.x) + sin(tn + i.y), sin(tn - i.y) + cos(tn + i.x));
        c += 1.0 / length(vec2(p.x / (sin(i.x + tn) / intensity), p.y / (cos(i.y + tn) / intensity)));
    }
    c /= 4.0;
    c = 1.17 - pow(c, 1.4);
    return pow(abs(c), 8.0);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    vec2 uv = fragCoord / iResolution.xy;
    float aspect = iResolution.x / iResolution.y;
    float t = mod(iTime, 1000.0);

    // The picture swaying in two slow waves across each other.
    vec2 at = uv + vec2(sin(uv.y * 18.0 + t * 1.3), cos(uv.x * 14.0 + t * 1.1)) * Sway;
    vec3 color = texture2D(iChannel0, at).rgb;

    // Water takes red first, then green, and hazes everything towards its
    // own colour, more so further down.
    color *= vec3(0.55, 0.85, 1.0);
    color = mix(color, Water, 0.25 + 0.25 * (1.0 - uv.y));

    // Sunlight from the surface, brightest near the top.
    float light = caustics(vec2(uv.x * aspect, uv.y) * 0.5, t * 0.5 + 23.0);
    color += vec3(0.6, 0.9, 1.0) * light * 0.3 * (0.35 + 0.65 * uv.y);

    fragColor = vec4(clamp(color, 0.0, 1.0), 1.0);
}
