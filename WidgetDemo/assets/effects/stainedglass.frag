// name: Stained Glass
// description: A stained glass window: the picture pieced together from
// description: irregular panes of glowing coloured glass, each one colour,
// description: held in dark lead.
// tags: art, glass, church, colour, color

// How big the panes are, in pixels across.
const float Pane = 42.0;

// How wide the lead between panes is, in pixels.
const float Lead = 3.0;

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

// The middle of a pane: one point in each square of a grid, placed at
// random within it, so the panes come out irregular. The window never
// changes, so neither do they.
vec2 paneMiddle(vec2 square)
{
    return square + 0.15 + 0.7 * vec2(hash2(square), hash2(square + 17.31));
}

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    vec2 p = fragCoord / Pane;
    vec2 square = floor(p);

    // Which pane this point is in: the nearest middle. How far the second
    // nearest is beyond it says how near the lead between them it is.
    float nearest = 10.0, second = 10.0;
    vec2 mine = vec2(0.0);
    for (int y = -1; y <= 1; y++)
        for (int x = -1; x <= 1; x++)
        {
            vec2 middle = paneMiddle(square + vec2(x, y));
            float d = length(p - middle);
            if (d < nearest)
            {
                second = nearest;
                nearest = d;
                mine = middle;
            }
            else if (d < second)
                second = d;
        }
    float toLead = (second - nearest) * Pane * 0.5;

    // The pane's one colour, from the picture at its middle and a little
    // around, deepened and brightened as light through glass is.
    vec2 uv = clamp(mine * Pane / iResolution.xy, 0.0, 1.0);
    vec2 pixel = 1.0 / iResolution.xy;
    vec3 color = (texture2D(iChannel0, uv).rgb * 2.0
        + texture2D(iChannel0, uv + vec2(pixel.x * 6.0, 0.0)).rgb
        + texture2D(iChannel0, uv - vec2(pixel.x * 6.0, 0.0)).rgb
        + texture2D(iChannel0, uv + vec2(0.0, pixel.y * 6.0)).rgb
        + texture2D(iChannel0, uv - vec2(0.0, pixel.y * 6.0)).rgb) / 6.0;
    float level = dot(color, vec3(0.2126, 0.7152, 0.0722));
    color = clamp(vec3(level) + (color - vec3(level)) * 1.5, 0.0, 1.0);
    color = pow(color, vec3(0.85)) * 1.1;

    // Old glass is never even: brighter towards a pane's middle, with
    // ripples and bubbles through it.
    color *= 1.05 - 0.2 * nearest;
    color *= 0.9 + 0.2 * noise2(fragCoord * 0.08);

    // The lead: dark, with a faint highlight along its crown.
    float lead = 1.0 - smoothstep(Lead * 0.5, Lead * 0.5 + 1.0, toLead);
    float crown = 1.0 - smoothstep(0.0, Lead * 0.35, toLead);
    vec3 leadColor = vec3(0.08, 0.08, 0.09) + vec3(0.12) * crown;
    fragColor = vec4(mix(clamp(color, 0.0, 1.0), leadColor, lead), 1.0);
}
