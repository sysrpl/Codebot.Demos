// name: Edge Neon
// description: The world of Tron: black everywhere, but every edge traced in
// description: glowing neon of its own colour, over a faint grid.
// tags: sci-fi, glow, games, outline, tron, dark

const vec3 Cyan = vec3(0.0, 0.85, 1.0);

// How far apart the lines of the grid are, in pixels.
const float GridSpacing = 64.0;

float brightness(vec2 uv)
{
    return dot(texture2D(iChannel0, uv).rgb, vec3(0.2126, 0.7152, 0.0722));
}

// How steeply brightness changes at a point, looking this far either side:
// a Sobel filter. Close in it finds sharp lines; further out it answers over
// a wider area, which makes the glow around them.
float edges(vec2 uv, vec2 d)
{
    float tl = brightness(uv + vec2(-d.x, d.y));
    float t = brightness(uv + vec2(0.0, d.y));
    float tr = brightness(uv + d);
    float l = brightness(uv - vec2(d.x, 0.0));
    float r = brightness(uv + vec2(d.x, 0.0));
    float bl = brightness(uv - d);
    float b = brightness(uv - vec2(0.0, d.y));
    float br = brightness(uv + vec2(d.x, -d.y));
    float gx = (tr + 2.0 * r + br) - (tl + 2.0 * l + bl);
    float gy = (tl + 2.0 * t + tr) - (bl + 2.0 * b + br);
    return length(vec2(gx, gy));
}

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    vec2 pixel = 1.0 / iResolution.xy;
    vec2 uv = fragCoord * pixel;

    float line = smoothstep(0.15, 0.4, edges(uv, pixel * 1.2));
    float glow = smoothstep(0.05, 0.6, edges(uv, pixel * 5.0));

    // The neon takes the colour of what it outlines, made as pure and bright
    // as it will go. Greys have no colour to give, so they glow cyan.
    vec3 color = texture2D(iChannel0, uv).rgb;
    float strongest = max(max(color.r, color.g), color.b);
    float weakest = min(min(color.r, color.g), color.b);
    float colourful = strongest > 0.0 ? (strongest - weakest) / strongest : 0.0;
    vec3 pure = color / max(strongest, 0.001);
    vec3 neon = mix(Cyan, pure, smoothstep(0.15, 0.4, colourful));

    // A white hot core along each line, the colour around it.
    vec3 result = neon * (line * 1.1 + glow * 0.45) + vec3(line * 0.35);

    // The grid, very faint, under everything.
    vec2 cell = mod(fragCoord, GridSpacing);
    float grid = 1.0 - smoothstep(0.0, 1.5, min(cell.x, cell.y));
    result += vec3(0.0, 0.06, 0.1) * grid;

    fragColor = vec4(clamp(result, 0.0, 1.0), 1.0);
}
