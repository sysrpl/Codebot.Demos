// name: Teletext
// description: The picture in the chunky blocks and eight bright colours of
// description: a Ceefax page: every character cell is six blocks, each lit or
// description: dark, in one colour on black.
// tags: retro, tv, text, pixel, blocks

// Character cells across and down. Each holds two blocks across and three
// down, which comes to nearly square blocks on a widescreen TV.
const vec2 Cells = vec2(60.0, 25.0);

// How bright a block must be to light.
const float Lit = 0.22;

float brightness(vec3 color)
{
    return dot(color, vec3(0.2126, 0.7152, 0.0722));
}

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    vec2 place = fragCoord / iResolution.xy * Cells;
    vec2 cell = floor(place);
    vec2 block = floor(fract(place) * vec2(2.0, 3.0));

    // Every block in the cell is looked at, for the cell's one colour, and
    // this block's own brightness decides whether it lights.
    vec3 total = vec3(0.0);
    float mine = 0.0;
    for (int y = 0; y < 3; y++)
        for (int x = 0; x < 2; x++)
        {
            vec2 b = vec2(x, y);
            vec3 color = texture2D(iChannel0, (cell + (b + 0.5) / vec2(2.0, 3.0)) / Cells).rgb;
            total += color;
            if (b == block)
                mine = brightness(color);
        }

    // Teletext has eight colours, each of red, green and blue fully on or
    // off. The cell's average colour is scaled so its strongest part is full,
    // which keeps its hue whatever its brightness, and each part then lights
    // if it is more than half of that.
    vec3 average = total / 6.0;
    float strongest = max(max(average.r, average.g), average.b);
    vec3 ink = step(vec3(0.55), average / max(strongest, 0.001));

    fragColor = vec4(mine > Lit ? ink : vec3(0.0), 1.0);
}
