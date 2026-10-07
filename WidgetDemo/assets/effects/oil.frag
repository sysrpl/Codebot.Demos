// name: Oil Painting
// description: Painted in oils on canvas: the picture in thick dabs of flat
// description: colour with crisp edges, a sheen of brush strokes, and the
// description: weave of the canvas showing through.
// tags: art, painting, canvas

// How far each dab of paint reaches, in pixels. Bigger is more painterly
// but costs no more: the samples just spread further.
const float Reach = 7.0;

// How much stronger colours are made.
const float Saturation = 1.15;

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

// One corner of the Kuwahara filter: the average colour of a square beside
// this point, and how much the brightness varies across it.
vec4 corner(vec2 uv, vec2 towards, vec2 pixel)
{
    vec3 sum = vec3(0.0);
    float sumSquares = 0.0;
    float sumLevels = 0.0;
    for (int y = 0; y < 3; y++)
        for (int x = 0; x < 3; x++)
        {
            vec2 offset = vec2(x, y) * towards * (Reach / 2.0);
            vec3 color = texture2D(iChannel0, uv + offset * pixel).rgb;
            float level = dot(color, vec3(0.2126, 0.7152, 0.0722));
            sum += color;
            sumLevels += level;
            sumSquares += level * level;
        }
    float mean = sumLevels / 9.0;
    return vec4(sum / 9.0, sumSquares / 9.0 - mean * mean);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    vec2 pixel = 1.0 / iResolution.xy;
    vec2 uv = fragCoord * pixel;

    // The Kuwahara filter: of the four squares with a corner here, take the
    // average of the one that varies least. Inside an area that is smooth
    // anyway; beside an edge, the square on this side of it wins, so edges
    // stay crisp while everything else turns to flat dabs of paint. Samples
    // fall between pixels, so each already averages four.
    vec4 best = corner(uv, vec2(-1.0, -1.0), pixel);
    vec4 next = corner(uv, vec2(1.0, -1.0), pixel);
    if (next.a < best.a) best = next;
    next = corner(uv, vec2(-1.0, 1.0), pixel);
    if (next.a < best.a) best = next;
    next = corner(uv, vec2(1.0, 1.0), pixel);
    if (next.a < best.a) best = next;
    vec3 color = best.rgb;
    float level = dot(color, vec3(0.2126, 0.7152, 0.0722));
    color = vec3(level) + (color - vec3(level)) * Saturation;

    // Brush strokes: streaks at a slant, lit from above left as the ridges
    // of thick paint would be, the height taken a pixel either side.
    mat2 slant = mat2(0.8, 0.6, -0.6, 0.8);
    vec2 s = slant * fragCoord;
    float here = noise2(vec2(s.x * 0.04, s.y * 0.5));
    float there = noise2(vec2((s.x + 1.0) * 0.04, (s.y + 1.0) * 0.5));
    color *= 0.95 + (here - there) * 0.6 + here * 0.08;

    // The canvas weave, faint through the paint.
    float weave = sin(fragCoord.x * 1.6) * sin(fragCoord.y * 1.6);
    color *= 0.97 + 0.03 * weave;

    fragColor = vec4(clamp(color, 0.0, 1.0), 1.0);
}
