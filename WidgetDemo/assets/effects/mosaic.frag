// name: Mosaic Tiles
// description: Set in small square tiles, each one colour, raised slightly
// description: and catching the light, with pale grout between them.
// tags: art, tiles, pixel

// How big a tile is, grout and all, in pixels.
const float Tile = 24.0;

// How wide the grout is, in pixels.
const float Grout = 2.0;

const vec3 GroutColor = vec3(0.78, 0.76, 0.72);

float hash2(vec2 p)
{
    vec3 p3 = fract(vec3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    vec2 place = fragCoord / Tile;
    vec2 cell = floor(place);
    vec2 inTile = fract(place) * Tile;

    // The tile's colour, averaged from four points across it, rounded to a
    // limited set of glazes, and each tile a little different from the next.
    vec3 color = vec3(0.0);
    for (int y = 0; y < 2; y++)
        for (int x = 0; x < 2; x++)
            color += texture2D(iChannel0, (cell + vec2(x, y) * 0.5 + 0.25) * Tile / iResolution.xy).rgb;
    color /= 4.0;
    color = floor(color * 8.0 + 0.5) / 8.0;
    color *= 0.92 + 0.16 * hash2(cell);

    // Raised: the light comes from above left, so a tile's top and left
    // edges are brighter and its bottom and right edges darker. Screen y
    // runs upwards, so its top is at the high end.
    float left = 1.0 - smoothstep(Grout, Tile * 0.2, inTile.x);
    float right = smoothstep(Tile * 0.8, Tile - Grout, inTile.x);
    float top = smoothstep(Tile * 0.8, Tile - Grout, inTile.y);
    float bottom = 1.0 - smoothstep(Grout, Tile * 0.2, inTile.y);
    color *= 1.0 + 0.15 * (left + top) - 0.2 * (right + bottom);

    // The grout around it.
    vec2 fromEdge = min(inTile, Tile - inTile);
    float grout = 1.0 - smoothstep(Grout * 0.5, Grout * 0.5 + 1.0, min(fromEdge.x, fromEdge.y));

    fragColor = vec4(mix(clamp(color, 0.0, 1.0), GroutColor, grout), 1.0);
}
