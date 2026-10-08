// name: Watercolour
// description: Painted in watercolour on rough white paper: pale, soft washes
// description: that bleed irregularly past their edges, darker where the
// description: pigment pooled at a wash's rim, and grainy with the paper.
// tags: art, painting, watercolor, soft

// How far colour bleeds past where it belongs, in pixels.
const float Bleed = 6.0;

// How pale the washes are, 0 as the picture was to 1 plain paper.
const float Paleness = 0.2;

const vec3 Paper = vec3(0.99, 0.97, 0.93);

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

float brightness(vec3 color)
{
    return dot(color, vec3(0.2126, 0.7152, 0.0722));
}

// The picture softened over a few pixels around a point.
vec3 wash(vec2 uv, vec2 pixel)
{
    vec3 sum = vec3(0.0);
    for (int y = -1; y <= 1; y++)
        for (int x = -1; x <= 1; x++)
            sum += texture2D(iChannel0, uv + vec2(x, y) * 3.0 * pixel).rgb;
    return sum / 9.0;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    vec2 pixel = 1.0 / iResolution.xy;

    // Bleeding: every point takes its colour from a little way off, in a
    // direction that wanders across the paper, so washes run ragged past
    // their edges. Fixed to the paper, as the fibres that lead it are.
    vec2 wander = vec2(noise2(fragCoord * 0.02), noise2(fragCoord * 0.02 + 31.7)) * 2.0 - 1.0;
    wander += (vec2(noise2(fragCoord * 0.08 + 7.1), noise2(fragCoord * 0.08 + 53.3)) * 2.0 - 1.0) * 0.4;
    vec2 uv = fragCoord * pixel + wander * Bleed * pixel;

    vec3 color = wash(uv, pixel);

    // Where a wash ends the pigment pools, drying darker at its rim: found
    // where the softened brightness changes, and darkening the colour there
    // without turning it grey.
    float gx = brightness(wash(uv + vec2(pixel.x * 4.0, 0.0), pixel)) - brightness(wash(uv - vec2(pixel.x * 4.0, 0.0), pixel));
    float gy = brightness(wash(uv + vec2(0.0, pixel.y * 4.0), pixel)) - brightness(wash(uv - vec2(0.0, pixel.y * 4.0), pixel));
    float rim = smoothstep(0.04, 0.2, length(vec2(gx, gy)));

    // Watercolour is pigment on white: the less colour, the more paper
    // shows. Worked as the amount of pigment, one minus the colour, it is
    // thinned out, pooled at the rims, and settles unevenly into the grain.
    vec3 pigment = (1.0 - color) * (1.0 - Paleness);
    pigment *= 1.0 + rim * 0.6;
    float grain = noise2(fragCoord * 0.35) * 0.6 + hash2(fragCoord) * 0.4;
    pigment *= 0.8 + 0.4 * grain;

    vec3 result = Paper * (1.0 - clamp(pigment, 0.0, 1.0));
    fragColor = vec4(result, 1.0);
}
