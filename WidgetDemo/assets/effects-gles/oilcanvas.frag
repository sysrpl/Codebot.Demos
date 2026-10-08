// name: Oil on Canvas
// description: Thick oil paint on a stretched canvas: the picture in flat
// description: dabs of colour with crisp edges, the paint standing up in
// description: ridges that catch the light with a glint on one side and a
// description: shadow on the other, and the canvas weave beneath.
// tags: art, painting, canvas, oil, impasto

// The relief lighting and the vignette are from the final pass of
// flockaroo's oil paint shader (Florian Berger, 2018), licensed Creative
// Commons Attribution-NonCommercial-ShareAlike 3.0, and so is this effect.
// His painting itself is built up in buffer passes this setup does not have,
// so the paint here comes from a Kuwahara filter instead, and the height the
// light falls on from the picture's broad shapes, brush strokes and weave.

// How far each dab of paint reaches, in pixels.
const float Reach = 7.0;

// How strongly the brush strokes and the weave raise the paint. The first
// is the ridges along the strokes, the second the canvas threads.
const float Strokes = 0.06;
const float Weave = 0.02;

// How far the paint's surface stands out: flockaroo's 150. Lower is bolder.
const float Flatness = 150.0;

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
            vec3 color = texture2D(iChannel0, uv + vec2(x, y) * towards * (Reach / 2.0) * pixel).rgb;
            float level = dot(color, vec3(0.2126, 0.7152, 0.0722));
            sum += color;
            sumLevels += level;
            sumSquares += level * level;
        }
    float mean = sumLevels / 9.0;
    return vec4(sum / 9.0, sumSquares / 9.0 - mean * mean);
}

// The picture softened over about this many pixels, standing in for a
// mipmap level: four samples spread around the point.
vec3 softened(vec2 uv, float across)
{
    vec2 d = across * 0.5 / iResolution.xy;
    return (texture2D(iChannel0, uv + vec2(d.x, d.y)).rgb
          + texture2D(iChannel0, uv + vec2(-d.x, d.y)).rgb
          + texture2D(iChannel0, uv + vec2(d.x, -d.y)).rgb
          + texture2D(iChannel0, uv + vec2(-d.x, -d.y)).rgb) * 0.25;
}

// How high the paint stands at a point. flockaroo's: the brightness of the
// painting at three levels of blur, 2.5, 1.5 and 0.5 mip levels in at
// 1080p, weighted .6, .3 and .2. Here, the picture at about those blurs, with
// ridges along brush strokes at a slant and the canvas threads added.
float height(vec2 uv)
{
    float h = length(softened(uv, 5.7)) * 0.6
            + length(softened(uv, 2.8)) * 0.3
            + length(softened(uv, 1.4)) * 0.2;
    vec2 at = uv * iResolution.xy;
    vec2 slant = mat2(0.8, 0.6, -0.6, 0.8) * at;
    h += noise2(vec2(slant.x * 0.04, slant.y * 0.5)) * Strokes;
    h += sin(at.x * 1.6) * sin(at.y * 1.6) * Weave;
    return h;
}

// The slope of the paint, from the heights either side.
vec2 slope(vec2 uv, float delta)
{
    vec2 d = vec2(delta, 0.0);
    return vec2(height(uv + d.xy) - height(uv - d.xy),
                height(uv + d.yx) - height(uv - d.yx)) / delta;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    vec2 pixel = 1.0 / iResolution.xy;
    vec2 uv = fragCoord * pixel;

    // The paint: of the four squares with a corner here, the average of the
    // one that varies least, so areas flatten into dabs and edges stay crisp.
    vec4 best = corner(uv, vec2(-1.0, -1.0), pixel);
    vec4 next = corner(uv, vec2(1.0, -1.0), pixel);
    if (next.a < best.a) best = next;
    next = corner(uv, vec2(-1.0, 1.0), pixel);
    if (next.a < best.a) best = next;
    next = corner(uv, vec2(1.0, 1.0), pixel);
    if (next.a < best.a) best = next;
    vec3 paint = best.rgb;

    // flockaroo's lighting: the surface's normal from its slope, lit from
    // one side, a cool glint where the light reflects towards the eye, and a
    // faint shadow from the other side.
    vec3 n = normalize(vec3(slope(uv, 1.0 / iResolution.y), Flatness));
    vec3 light = normalize(vec3(1.0, -1.0, 0.8));
    float diff = clamp(dot(n, light), 0.0, 1.0);
    float spec = clamp(dot(reflect(light, n), vec3(0.0, 0.0, -1.0)), 0.0, 1.0);
    spec = pow(spec, 12.0) * 0.5;
    float sh = clamp(dot(reflect(light * vec3(-1.0, -1.0, 1.0), n), vec3(0.0, 0.0, -1.0)), 0.0, 1.0);
    sh = pow(sh, 4.0) * 0.1;
    vec3 color = paint * mix(diff, 1.0, 0.8) + spec * vec3(0.85, 1.0, 1.15) - sh * vec3(0.85, 1.0, 1.15);

    // flockaroo's vignette: darker to the corners, and falling away sharply
    // at the very edges, like a canvas's edge wrapping round its frame.
    vec2 scc = (fragCoord - 0.5 * iResolution.xy) / iResolution.x;
    float vign = 1.3 - 2.5 * dot(scc, scc);
    vign *= 1.0 - 0.8 * exp(-sin(fragCoord.x / iResolution.x * 3.1416) * 20.0);
    vign *= 1.0 - 0.8 * exp(-sin(fragCoord.y / iResolution.y * 3.1416) * 10.0);
    color *= vign;

    fragColor = vec4(clamp(color, 0.0, 1.0), 1.0);
}
