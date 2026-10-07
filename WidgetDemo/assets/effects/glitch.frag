// name: Glitch
// description: A corrupted digital signal: mostly clean, but in sudden bursts
// description: the picture tears into slices that jump sideways, its colours
// description: split apart, and blocks break up into garbage.
// tags: digital, noise, error, glitch

// How often the signal is looked at to decide whether it glitches, a second.
const float Checks = 10.0;

// How much of the time it glitches, 0 never to 1 always.
const float Glitchiness = 0.25;

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

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    vec2 uv = fragCoord / iResolution.xy;
    float moment = mod(floor(iTime * Checks), 4096.0);

    // How badly this moment glitches: nothing most of the time, sometimes a
    // little, now and then a lot.
    float strength = smoothstep(1.0 - Glitchiness, 1.0, hash(moment * 1.13));

    // Tearing: the picture cut into slices of a height chosen for the moment,
    // about half of them thrown sideways, wrapping round at the edges.
    float sliceHeight = mix(0.01, 0.08, hash(moment * 1.31));
    float slice = floor(uv.y / sliceHeight);
    float thrown = step(0.5, hash(slice * 3.1 + moment));
    float x = fract(uv.x + (hash(slice + moment * 7.7) - 0.5) * 0.15 * strength * thrown);

    // The colours split apart: red one way, blue the other. Always a touch,
    // far more in a burst.
    float split = 0.0015 + 0.02 * strength;
    vec3 color = vec3(texture2D(iChannel0, vec2(x + split, uv.y)).r,
                      texture2D(iChannel0, vec2(x, uv.y)).g,
                      texture2D(iChannel0, vec2(x - split, uv.y)).b);

    // Broken blocks: some squares taken from somewhere else in the picture,
    // with their colours crushed, and some of those inverted.
    vec2 block = floor(fragCoord / 48.0);
    if (hash2(block + moment * 3.7) > 1.0 - 0.18 * strength)
    {
        vec2 from = fract(uv + (vec2(hash2(block * 1.7 + moment), hash2(block * 2.3 + moment)) - 0.5) * 0.3);
        color = floor(texture2D(iChannel0, from).rgb * 4.0) / 4.0;
        if (hash2(block + moment * 5.1) > 0.6)
            color = 1.0 - color;
    }

    // Lines of snow across the picture.
    if (hash(floor(fragCoord.y) + moment * 13.0) > 1.0 - 0.03 * strength)
        color = vec3(hash2(fragCoord + moment));

    fragColor = vec4(color, 1.0);
}
