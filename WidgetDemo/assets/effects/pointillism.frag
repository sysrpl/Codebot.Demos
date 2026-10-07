// name: Pointillism
// description: Painted in dots, like a Seurat: the picture made of small
// description: overlapping dabs of pure, bright colour on a pale canvas,
// description: blending together in the eye.
// tags: art, painting, dots

// How far apart the dots are, in pixels.
const float Spacing = 7.0;

const vec3 Canvas = vec3(0.95, 0.93, 0.87);

float hash2(vec2 p)
{
    vec3 p3 = fract(vec3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    vec2 p = fragCoord / Spacing;
    vec2 square = floor(p);

    // One dot per square of a grid, placed and sized at random, and painted
    // in a random order. The dots of the squares around can reach over this
    // point too, so all nine are looked at, and the one painted last wins.
    float topOrder = -1.0;
    vec2 topMiddle = vec2(0.0);
    float topCover = 0.0;
    float topSeed = 0.0;
    for (int y = -1; y <= 1; y++)
        for (int x = -1; x <= 1; x++)
        {
            vec2 cell = square + vec2(x, y);
            vec2 middle = cell + 0.5 + (vec2(hash2(cell), hash2(cell + 3.7)) - 0.5) * 0.8;
            float radius = (0.45 + 0.25 * hash2(cell + 9.1)) * Spacing;
            float d = length(p - middle) * Spacing;
            float cover = 1.0 - smoothstep(radius - 1.0, radius, d);
            float order = hash2(cell + 5.3);
            if (cover > 0.0 && order > topOrder)
            {
                topOrder = order;
                topMiddle = middle;
                topCover = cover;
                topSeed = hash2(cell + 11.9);
            }
        }

    // The dot's colour from the picture at its middle, made purer and
    // brighter, and each dot a touch lighter or darker than the next, as
    // no two dabs of paint are quite alike.
    vec3 color = texture2D(iChannel0, clamp(topMiddle * Spacing / iResolution.xy, 0.0, 1.0)).rgb;
    float level = dot(color, vec3(0.2126, 0.7152, 0.0722));
    color = clamp(vec3(level) + (color - vec3(level)) * 1.5, 0.0, 1.0);
    color *= 0.9 + 0.2 * topSeed;

    fragColor = vec4(mix(Canvas, color, topCover), 1.0);
}
