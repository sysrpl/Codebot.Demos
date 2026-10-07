// name: Amber Terminal
// description: The picture typed out in amber letters on an old computer
// description: terminal, with scan lines, a soft glow and the faint flicker
// description: of the tube.
// tags: retro, text, ascii, computer, amber

// Characters across and down. At 1080p each cell is 15 pixels square.
const vec2 Grid = vec2(128.0, 72.0);

const vec3 Amber = vec3(1.0, 0.62, 0.12);

float hash(float n)
{
    n = fract(n * 0.1031);
    n *= n + 33.33;
    n *= n + n;
    return fract(n);
}

float brightness(vec3 color)
{
    return dot(color, vec3(0.2126, 0.7152, 0.0722));
}

// The letter's coverage at a point in its cell, from the glyph atlas, whose
// top row is first where the cell has its bottom.
float letter(float glyph, vec2 at)
{
    at = clamp(at, 0.0, 1.0);
    return texture2D(iChannel1, vec2((glyph + at.x) / iGlyphs, 1.0 - at.y)).a;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    vec2 place = fragCoord / iResolution.xy * Grid;
    vec2 cell = floor(place);
    vec2 inCell = fract(place);

    // The cell's brightness from nine points across it, with a little more
    // contrast, picks the letter: the fuller the letter, the brighter.
    float level = 0.0;
    for (int y = 0; y < 3; y++)
        for (int x = 0; x < 3; x++)
            level += brightness(texture2D(iChannel0, (cell + (vec2(x, y) + 0.5) / 3.0) / Grid).rgb);
    level = clamp((level / 9.0 - 0.04) * 1.2, 0.0, 1.0);
    float glyph = floor(level * (iGlyphs - 1.0) + 0.5);

    // Sharp from four samples a quarter of a pixel apart; glowing from four
    // more, spread wider, as the phosphor bleeds around each stroke.
    vec2 pixel = Grid / iResolution.xy;
    float ink = 0.0, glow = 0.0;
    for (int y = 0; y < 2; y++)
        for (int x = 0; x < 2; x++)
        {
            vec2 corner = vec2(x, y) - 0.5;
            ink += letter(glyph, inCell + corner * 0.5 * pixel);
            glow += letter(glyph, inCell + corner * 3.0 * pixel);
        }
    ink /= 4.0;
    glow /= 4.0;

    vec3 color = Amber * (ink * (0.45 + 0.75 * level) + glow * 0.35);
    // The glass is never quite black.
    color += Amber * 0.03;

    // Scan lines every three pixels, and the whole tube flickering faintly.
    color *= 0.82 + 0.18 * cos(6.2831853 * fragCoord.y / 3.0);
    color *= 1.0 + (hash(mod(floor(iTime * 60.0), 4096.0)) - 0.5) * 0.04;

    fragColor = vec4(clamp(color, 0.0, 1.0), 1.0);
}
