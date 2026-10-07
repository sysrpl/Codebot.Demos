// name: Newspaper Print
// description: A photo in a newspaper: black ink in a screen of dots, bigger
// description: where it is darker, on cheap grey-yellow newsprint.
// tags: print, dots, black and white, retro

// The distance between dots, in pixels.
const float DotSpacing = 6.0;

const vec3 Newsprint = vec3(0.9, 0.88, 0.8);
const vec3 Ink = vec3(0.1, 0.1, 0.12);

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

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    vec2 pixel = 1.0 / iResolution.xy;

    // The dot screen, turned 45 degrees, as the eye notices the rows least
    // that way. Each dot's size comes from the picture at its middle.
    mat2 turn = mat2(0.7071, 0.7071, -0.7071, 0.7071);
    mat2 back = mat2(0.7071, -0.7071, 0.7071, 0.7071);
    vec2 place = turn * fragCoord / DotSpacing;
    vec2 middle = back * ((floor(place) + 0.5) * DotSpacing);
    vec3 color = texture2D(iChannel0, clamp(middle * pixel, 0.0, 1.0)).rgb;
    float level = dot(color, vec3(0.2126, 0.7152, 0.0722));
    // Newspaper photos print flat and contrasty.
    float ink = clamp((1.0 - level - 0.1) * 1.3, 0.0, 1.0);

    // A dot covering as much of its cell as the ink should, its edge a
    // little ragged where ink soaked into the paper.
    float radius = DotSpacing * sqrt(ink / 3.14159);
    float apart = length(fract(place) - 0.5) * DotSpacing;
    apart += (noise2(fragCoord * 0.9) - 0.5) * 0.8;
    // Faded out as it shrinks to nothing, so white stays white.
    float spot = (1.0 - smoothstep(radius - 0.6, radius + 0.6, apart)) * smoothstep(0.0, 0.8, radius);

    // Newsprint: blotchy, fibrous and never white.
    float paper = noise2(fragCoord * 0.05) * 0.5 + noise2(fragCoord * 0.4) * 0.3 + hash2(fragCoord) * 0.2;
    vec3 sheet = Newsprint * (0.94 + 0.08 * paper);

    fragColor = vec4(mix(sheet, Ink, spot * 0.95), 1.0);
}
