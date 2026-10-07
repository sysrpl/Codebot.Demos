// name: Hologram
// description: A flickering blue hologram: the scene glowing translucent cyan,
// description: brightest at its edges, with scan lines rising through it, a
// description: bright band sweeping up, and now and then a glitch.
// tags: sci-fi, blue, glitch, star wars

const vec3 Tint = vec3(0.3, 0.8, 1.0);

float hash(float n)
{
    n = fract(n * 0.1031);
    n *= n + 33.33;
    n *= n + n;
    return fract(n);
}

float brightness(vec2 uv)
{
    return dot(texture2D(iChannel0, uv).rgb, vec3(0.2126, 0.7152, 0.0722));
}

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    vec2 pixel = 1.0 / iResolution.xy;
    vec2 uv = fragCoord * pixel;
    float t = mod(iTime, 1000.0);

    // Now and then, for a moment, bands of lines slip sideways.
    float moment = floor(t * 12.0);
    float glitching = step(0.9, hash(floor(t * 3.0)));
    uv.x += (hash(floor(uv.y * 40.0) + moment) - 0.5) * 0.02 * glitching;

    // The scene's brightness, and its edges, which a hologram draws brightest.
    float level = brightness(uv);
    float dx = brightness(uv + vec2(pixel.x * 1.5, 0.0)) - brightness(uv - vec2(pixel.x * 1.5, 0.0));
    float dy = brightness(uv + vec2(0.0, pixel.y * 1.5)) - brightness(uv - vec2(0.0, pixel.y * 1.5));
    float edge = smoothstep(0.05, 0.3, length(vec2(dx, dy)));
    vec3 color = Tint * (level * 0.7 + edge * 0.9);

    // Fine scan lines rising steadily, and a broad bright band sweeping up
    // every few seconds.
    color *= 0.7 + 0.3 * sin((fragCoord.y - t * 40.0) * 0.6);
    float sweep = fract(uv.y * 0.5 - t * 0.2) - 0.5;
    color += Tint * 0.25 * exp(-sweep * sweep * 60.0);

    // Flicker, and a faint glow of its own where the picture is dark, so it
    // reads as light hanging in the air.
    color *= 0.88 + 0.12 * hash(floor(t * 30.0));
    color += Tint * 0.04;

    fragColor = vec4(clamp(color, 0.0, 1.0), 1.0);
}
