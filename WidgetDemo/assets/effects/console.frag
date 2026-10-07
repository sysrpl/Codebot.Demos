// name: 8-bit Console
// description: Big chunky pixels in the 64 colours of an 8-bit games
// description: console, dithered where one colour shades into the next.
// tags: retro, games, pixel, 8-bit

// The console's screen, in its own pixels. Each is six real ones at 1080p.
const vec2 Grid = vec2(320.0, 180.0);

// Levels of each of red, green and blue: 4 x 4 x 4 gives 64 colours, as on
// the Sega Master System.
const float Levels = 4.0;

// An ordered dither pattern: a fixed 4 by 4 tile of thresholds, from 0 to
// just under 1, built from the 2 by 2 one inside it.
float bayer2(vec2 a)
{
    a = floor(a);
    return fract(dot(a, vec2(0.5, a.y * 0.75)));
}

float bayer4(vec2 a)
{
    return bayer2(0.5 * a) * 0.25 + bayer2(a);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    vec2 cell = floor(fragCoord / iResolution.xy * Grid);

    // The big pixel's colour, averaged from four points inside it.
    vec3 color = vec3(0.0);
    for (int y = 0; y < 2; y++)
        for (int x = 0; x < 2; x++)
            color += texture2D(iChannel0, (cell + vec2(x, y) * 0.5 + 0.25) / Grid).rgb;
    color /= 4.0;

    // Each pixel nudged up or down by the pattern before it is rounded to
    // the nearest level, so a smooth shade becomes a fine mix of the two
    // colours either side of it rather than a hard band.
    float threshold = bayer4(cell) - 0.5;
    color = floor(color * (Levels - 1.0) + 0.5 + threshold) / (Levels - 1.0);

    fragColor = vec4(clamp(color, 0.0, 1.0), 1.0);
}
