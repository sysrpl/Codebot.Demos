// name: Terminator HUD
// description: Through the Terminator's eyes: the scene in shades of red with
// description: scan lines, a targeting reticle sweeping across it, and
// description: streams of analysis read-outs scrolling in the corner.
// tags: sci-fi, red, movie, hud, robot, text

const vec3 Red = vec3(1.0, 0.12, 0.08);
const vec3 Readout = vec3(1.0, 0.85, 0.85);

// The read-out panel's characters, in pixels square.
const float Letter = 14.0;

float hash(float n)
{
    n = fract(n * 0.1031);
    n *= n + 33.33;
    n *= n + n;
    return fract(n);
}

// The letter's coverage at a point in its cell, from the glyph atlas, whose
// top row is first where the cell has its bottom.
float letter(float glyph, vec2 at)
{
    at = clamp(at, 0.0, 1.0);
    return texture2D(iChannel1, vec2((glyph + at.x) / iGlyphs, 1.0 - at.y)).a;
}

// A ring, a line or a bracket drawn a couple of pixels wide.
float stroke(float away)
{
    return 1.0 - smoothstep(1.0, 2.0, abs(away));
}

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    vec2 uv = fragCoord / iResolution.xy;
    float t = mod(iTime, 1000.0);

    // The scene: its brightness, with hard contrast, in red, with scan lines.
    float level = dot(texture2D(iChannel0, uv).rgb, vec3(0.2126, 0.7152, 0.0722));
    level = smoothstep(0.05, 0.9, level);
    vec3 color = Red * level + vec3(0.1, 0.0, 0.0);
    color *= 0.85 + 0.15 * cos(fragCoord.y * 3.14159);

    // The reticle, wandering slowly over the scene: a ring, a cross with a
    // gap in its middle, and brackets at the corners of a box around it.
    vec2 centre = vec2(0.5, 0.5) + vec2(sin(t * 0.37), sin(t * 0.53)) * vec2(0.18, 0.14);
    vec2 p = (uv - centre) * iResolution.xy;
    float mark = stroke(length(p) - 70.0);
    if (abs(p.x) > 20.0 && abs(p.x) < 110.0) mark = max(mark, stroke(p.y));
    if (abs(p.y) > 20.0 && abs(p.y) < 110.0) mark = max(mark, stroke(p.x));
    vec2 corner = abs(p) - vec2(130.0);
    if (corner.x > -30.0 && corner.x < 2.0 && corner.y > -30.0 && corner.y < 2.0)
        mark = max(mark, max(stroke(corner.x), stroke(corner.y)));
    color = mix(color, Readout, mark);

    // The read-outs: a panel of lines in the top right, each a run of
    // letters of its own length, scrolling up a line four times a second.
    vec2 panelFrom = vec2(0.66, 0.55) * iResolution.xy;
    vec2 panelTo = vec2(0.96, 0.93) * iResolution.xy;
    if (fragCoord.x > panelFrom.x && fragCoord.x < panelTo.x && fragCoord.y > panelFrom.y && fragCoord.y < panelTo.y)
    {
        vec2 place = (fragCoord - vec2(panelFrom.x, panelTo.y)) / Letter;
        float row = floor(-place.y);
        float column = floor(place.x);
        float line = row + floor(t * 4.0);
        float run = 6.0 + floor(hash(line * 1.7) * 16.0);
        if (column < run && hash(line * 3.1) > 0.15)
        {
            // Fuller letters rather than dots and dashes, which read as text.
            float glyph = floor(iGlyphs * (0.35 + 0.6 * hash(line * 7.3 + column * 1.9)));
            vec2 inCell = fract(vec2(place.x, place.y));
            color = mix(color, Readout, letter(glyph, inCell) * 0.9);
        }
    }

    fragColor = vec4(clamp(color, 0.0, 1.0), 1.0);
}
