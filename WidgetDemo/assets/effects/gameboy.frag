// name: Game Boy
// description: Four shades of green on big square pixels, like the screen of
// description: the original Game Boy, with a faint grid between the pixels.
// tags: retro, games, pixel, green, handheld

// The screen, in its own pixels. Each is eight real ones at 1080p.
const vec2 Grid = vec2(240.0, 135.0);

// The Game Boy's four shades, darkest to lightest.
const vec3 Shade0 = vec3(15.0, 56.0, 15.0) / 255.0;
const vec3 Shade1 = vec3(48.0, 98.0, 48.0) / 255.0;
const vec3 Shade2 = vec3(139.0, 172.0, 15.0) / 255.0;
const vec3 Shade3 = vec3(155.0, 188.0, 15.0) / 255.0;

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
    vec2 place = fragCoord / iResolution.xy * Grid;
    vec2 cell = floor(place);

    float level = 0.0;
    for (int y = 0; y < 2; y++)
        for (int x = 0; x < 2; x++)
            level += dot(texture2D(iChannel0, (cell + vec2(x, y) * 0.5 + 0.25) / Grid).rgb,
                         vec3(0.2126, 0.7152, 0.0722));
    // A little more contrast, since four shades flatten a picture a lot.
    level = clamp((level / 4.0 - 0.05) * 1.15, 0.0, 1.0);

    // Dithered to the nearest of the four shades.
    float shade = floor(level * 3.0 + 0.5 + bayer4(cell) - 0.5);
    vec3 color = shade < 0.5 ? Shade0 : shade < 1.5 ? Shade1 : shade < 2.5 ? Shade2 : Shade3;

    // The thin gaps between pixels, a little darker.
    vec2 inCell = fract(place);
    float gap = smoothstep(0.8, 0.95, max(inCell.x, inCell.y));
    color *= 1.0 - 0.18 * gap;

    fragColor = vec4(color, 1.0);
}
