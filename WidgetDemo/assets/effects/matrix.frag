// name: The Matrix
// description: The picture rebuilt from green Courier letters, 160 across and
// description: 90 down, each chosen by how much of its cell it fills to match
// description: the brightness underneath.
// tags: sci-fi, text, ascii, green, movie

// The grid of characters. At 1080p each cell is 12 pixels square.
const vec2 Grid = vec2(160.0, 90.0);

float brightness(vec3 color)
{
    return dot(color, vec3(0.2126, 0.7152, 0.0722));
}

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    vec2 place = fragCoord / iResolution.xy * Grid;
    vec2 cell = floor(place);
    vec2 inCell = fract(place);

    // The cell's brightness, averaged from nine points spread across it, so
    // fine detail and noise inside a cell don't make its letter flicker.
    float level = 0.0;
    for (int y = 0; y < 3; y++)
        for (int x = 0; x < 3; x++)
            level += brightness(texture2D(iChannel0, (cell + (vec2(x, y) + 0.5) / 3.0) / Grid).rgb);
    level /= 9.0;
    // A little more contrast, so dark scenes still reach the fuller letters.
    level = clamp((level - 0.04) * 1.2, 0.0, 1.0);

    // The atlas runs from the space up to the fullest letter.
    float glyph = floor(level * (iGlyphs - 1.0) + 0.5);

    // The letter's coverage at this pixel, from four points inside it: each
    // screen pixel covers more than two of the atlas's, so one sample alone
    // would shimmer. Clamped to the cell, so a sample never reaches the next
    // letter along.
    vec2 pixel = Grid / iResolution.xy;
    float ink = 0.0;
    for (int y = 0; y < 2; y++)
        for (int x = 0; x < 2; x++)
        {
            vec2 at = clamp(inCell + (vec2(x, y) - 0.5) * 0.5 * pixel, 0.0, 1.0);
            // The atlas has its top row first, where the cell has its bottom.
            ink += texture2D(iChannel1, vec2((glyph + at.x) / iGlyphs, 1.0 - at.y)).a;
        }
    ink /= 4.0;

    // Deep green in the shadows to a pale, nearly white green in the
    // highlights, the brighter letters glowing more strongly.
    vec3 green = mix(vec3(0.05, 0.6, 0.15), vec3(0.75, 1.0, 0.8), level * level);
    fragColor = vec4(green * ink * (0.5 + 0.7 * level), 1.0);
}
